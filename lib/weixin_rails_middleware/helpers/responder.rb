require 'English'

module WeixinRailsMiddleware
  module Responder
    extend ActiveSupport::Concern
    include ReplyWeixinMessageHelper

    included do
      before_action :check_is_encrypt, only: [:index, :reply]
      before_action :initialize_adapter, :check_weixin_legality, only: [:index, :reply]
      before_action :set_weixin_public_account, :set_weixin_message, only: :reply
    end

    module ClassMethods
      # @detail https://github.com/Eric-Guo/wechat/blob/master/lib/wechat/responder.rb
      def on(message_type, with: nil, respond: nil, &block)
        raise 'Unknow message type' unless [:text, :image, :voice, :video, :shortvideo, :link, :event, :click, :view, :scan, :batch_job, :location, :label_location, :fallback].include?(message_type)
        config = respond.nil? ? {} : { respond: respond }
        config[:proc] = block if block_given?

        if with.present?
          raise 'Only text, event, click, view, scan and batch_job can having :with parameters' unless [:text, :event, :click, :view, :scan, :batch_job].include?(message_type)
          config[:with] = with
          if message_type == :scan
            if with.is_a?(String)
              self.known_scan_key_lists = with
            else
              raise 'on :scan only support string in parameter with, detail see https://github.com/Eric-Guo/wechat/issues/84'
            end
          end
        else
          raise 'Message type click, view, scan and batch_job must specify :with parameters' if [:click, :view, :scan, :batch_job].include?(message_type)
        end

        case message_type
        when :click
          user_defined_click_responders(with) << config
        when :view
          user_defined_view_responders(with) << config
        when :batch_job
          user_defined_batch_job_responders(with) << config
        when :scan
          user_defined_scan_responders << config
        when :location
          user_defined_location_responders << config
        when :label_location
          user_defined_label_location_responders << config
        else
          user_defined_responders(message_type) << config
        end

        config
      end

      def user_defined_click_responders(with)
        @click_responders ||= {}
        @click_responders[with] ||= []
      end

      def user_defined_view_responders(with)
        @view_responders ||= {}
        @view_responders[with] ||= []
      end

      def user_defined_batch_job_responders(with)
        @batch_job_responders ||= {}
        @batch_job_responders[with] ||= []
      end

      def user_defined_scan_responders
        @scan_responders ||= []
      end

      def user_defined_location_responders
        @location_responders ||= []
      end

      def user_defined_label_location_responders
        @label_location_responders ||= []
      end

      def user_defined_responders(type)
        @responders ||= {}
        @responders[type] ||= []
      end

      def responder_for(message)
        message_type = message[:MsgType].to_sym
        responders = user_defined_responders(message_type)

        case message_type
        when :text
          yield(* match_responders(responders, message[:Content]))
        when :event
          if 'click' == message[:Event] && !user_defined_click_responders(message[:EventKey]).empty?
            yield(* user_defined_click_responders(message[:EventKey]), message[:EventKey])
          elsif 'view' == message[:Event] && !user_defined_view_responders(message[:EventKey]).empty?
            yield(* user_defined_view_responders(message[:EventKey]), message[:EventKey])
          elsif 'click' == message[:Event]
            yield(* match_responders(responders, message[:EventKey]))
          elsif known_scan_key_lists.include?(message[:EventKey]) && %w(scan subscribe scancode_push scancode_waitmsg).freeze.include?(message[:Event])
            yield(* known_scan_with_match_responders(user_defined_scan_responders, message))
          elsif 'batch_job_result' == message[:Event]
            yield(* user_defined_batch_job_responders(message[:BatchJob][:JobType]), message[:BatchJob])
          elsif 'location' == message[:Event]
            yield(* user_defined_location_responders, message)
          else
            yield(* match_responders(responders, message[:Event]))
          end
        when :location
          yield(* user_defined_label_location_responders, message)
        else
          yield(responders.first)
        end
      end

      private

      def match_responders(responders, value)
        matched = responders.each_with_object({}) do |responder, memo|
          condition = responder[:with]

          if condition.nil?
            memo[:general] ||= [responder, value]
            next
          end

          if condition.is_a? Regexp
            memo[:scoped] ||= [responder] + $LAST_MATCH_INFO.captures if value =~ condition
          else
            memo[:scoped] ||= [responder, value] if value == condition
          end
        end
        matched[:scoped] || matched[:general]
      end

      def known_scan_with_match_responders(responders, message)
        matched = responders.each_with_object({}) do |responder, memo|
          if %w(scan subscribe).freeze.include?(message[:Event]) && message[:EventKey] == responder[:with]
            memo[:scaned] ||= [responder, message[:Ticket]]
          elsif %w(scancode_push scancode_waitmsg).freeze.include?(message[:Event]) && message[:EventKey] == responder[:with]
            memo[:scaned] ||= [responder, message[:ScanCodeInfo][:ScanResult], message[:ScanCodeInfo][:ScanType]]
          end
        end
        matched[:scaned]
      end

      def known_scan_key_lists
        @known_scan_key_lists ||= []
      end

      def known_scan_key_lists=(qrscene_value)
        @known_scan_key_lists ||= []
        @known_scan_key_lists << qrscene_value
      end
    end

    def index
      render_text params[:echostr]
    end

    def reply
      render_text run_responder(@weixin_message)
    end

    protected

    # 如果url上无encrypt_type或者其值为raw，则回复明文，否则按照上述的加密算法加密回复密文。
    def check_is_encrypt
      if params[:encrypt_type].blank? || params[:encrypt_type] == "raw"
        @is_encrypt = false
      else
        @is_encrypt = true
      end
    end

    def initialize_adapter
      @weixin_adapter ||= WexinAdapter.init_with(params)
    end

    def check_weixin_legality
      check_result = @weixin_adapter.check_weixin_legality
      return if check_result.delete(:valid)
      render check_result
    end

    ## Callback
    # e.g. will generate +@weixin_public_account+
    def set_weixin_public_account
      @weixin_public_account ||= @weixin_adapter.current_weixin_public_account
    end

    def set_weixin_message
      param_xml = request.body.read
      if @is_encrypt
        hash      = MultiXml.parse(param_xml)['xml']
        @body_xml = OpenStruct.new(hash)
        param_xml = Prpcrypt.decrypt(@weixin_public_account.aes_key,
                                      @body_xml.Encrypt,
                                      @weixin_public_account.app_id
                                      )[0]
      end
      # Get the current weixin message
      @weixin_message ||= Message.factory(param_xml)
    end

    def run_responder(request)
      self.class.responder_for(request) do |responder, *args|
        responder ||= self.class.user_defined_responders(:fallback).first

        next if responder.nil?
        case
        when responder[:respond]
          reply_text_message responder[:respond]
        when responder[:proc]
          define_singleton_method :process, responder[:proc]
          number_of_block_parameter = responder[:proc].arity
          send(:process, *args.unshift(request).take(number_of_block_parameter))
        else
          next
        end
      end
    end

    # http://apidock.com/rails/ActionController/Base/default_url_options
    def default_url_options(options={})
      { weichat_id: @weixin_message.FromUserName }
    end

    def render_text(text)
      if Rails::VERSION::MAJOR >= 4
        render plain: text
      else
        render text: text
      end
    end
  end
end