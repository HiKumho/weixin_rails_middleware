# encoding: utf-8
module WeixinRailsMiddleware
  module Responder
    extend ActiveSupport::Concern
    include ReplyWeixinMessageHelper

    included do
      before_filter :check_is_encrypt, only: [:index, :reply]
      before_filter :initialize_adapter, :check_weixin_legality, only: [:index, :reply]
      before_filter :set_weixin_public_account, :set_weixin_message, only: :reply
      before_filter :set_keyword, only: :reply
      before_filter :run_responder, only: :reply
    end

    module ClassMethods
      # @detail https://github.com/Eric-Guo/wechat/blob/master/lib/wechat/responder.rb
      def on(message_type, with: nil, respond: nil, &block)
        raise 'Unknow message type' unless [:text, :image, :voice, :video, :shortvideo, :link, :event, :click, :view, :scan, :batch_job, :location, :label_location, :fallback].include?(message_type)
        config = respond.nil? ? {} : { respond: respond }
        config[:proc] = block if block_given?


      end

      def user_defined_responders(type)
        @responders ||= {}
        @responders[type] ||= []
      end

      def responder_for(message)
        message_type = message.MsgType.to_sym
        responders = user_defined_responders(message_type)

        case message_type
        when :text
        when :event
        when :location
        else
        end
      end 
    end

    def index
      if Rails::VERSION::MAJOR >= 4
        render plain: params[:echostr]
      else
        render text: params[:echostr]
      end
    end

    def reply; end

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

    def set_keyword
      @keyword = @weixin_message.Content  || # 文本消息
                  @weixin_message.EventKey || # 事件推送
                  @weixin_message.Recognition # 接收语音识别结果
    end

    def run_responder
    end

    # http://apidock.com/rails/ActionController/Base/default_url_options
    def default_url_options(options={})
      { weichat_id: @weixin_message.FromUserName }
    end
  end
end