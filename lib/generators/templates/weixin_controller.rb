# encoding: utf-8
# @params @weixin_message(request)   获取微信所有参数.
# @params @weixin_public_account     如果配置了public_account_class选项,则会返回当前实例,否则返回 nil
# @detail WeixinRailsMiddleware::Responder
# @thanks https://github.com/Eric-Guo/wechat
class WeixinController < ActionController::Base
  include WeixinRailsMiddleware::Responder

  # default text responder when no other match
  on :text do |request, content|
    reply_text_message "echo: #{content}" # Just echo
  end

  # When receive 'help', will trigger this responder
  on :text, with: 'help' do |request|
    reply_text_message 'help content'
  end

  # When receive '<n>news', will match and will get count as <n> as parameter
  on :text, with: /^(\d+) news$/ do |request, count|
    # weixin article can only contain max 8 items, large than 8 will be dropped.
    reply_news_message (1..count.to_i).each_with_index.map do |article, index|
      generate_article('News title', "No. #{index} news content", 'http://www.baidu.com/img/bdlogo.gif', 'http://www.baidu.com/')
    end
  end

  on :event, with: 'subscribe' do |request|
    reply_text_message "#{request[:FromUserName]} subscribe now"
  end

  # When unsubscribe user scan qrcode qrscene_xxxxxx to subscribe in public account
  # notice user will subscribe public account at the same time, so weixin won't trigger subscribe event anymore
  on :scan, with: 'qrscene_xxxxxx' do |request, ticket|
    reply_text_message "Unsubscribe user #{request[:FromUserName]} Ticket #{ticket}"
  end

  # When subscribe user scan scene_id in public account
  on :scan, with: 'scene_id' do |request, ticket|
    reply_text_message "Subscribe user #{request[:FromUserName]} Ticket #{ticket}"
  end

  # When no any on :scan responder can match subscribe user scanned scene_id
  on :event, with: 'scan' do |request|
    if request[:EventKey].present?
      reply_text_message "event scan got EventKey #{request[:EventKey]} Ticket #{request[:Ticket]}"
    end
  end

  # When enterprise user press menu BINDING_QR_CODE and success to scan bar code
  on :scan, with: 'BINDING_QR_CODE' do |request, scan_result, scan_type|
    reply_text_message "User #{request[:FromUserName]} ScanResult #{scan_result} ScanType #{scan_type}"
  end

  # Except QR code, weixin can also scan CODE_39 bar code in enterprise account
  on :scan, with: 'BINDING_BARCODE' do |message, scan_result|
    if scan_result.start_with? 'CODE_39,'
      reply_text_message "User: #{message[:FromUserName]} scan barcode, result is #{scan_result.split(',')[1]}"
    end
  end

  # When user clicks the menu button
  on :click, with: 'BOOK_LUNCH' do |request, key|
    reply_text_message "User: #{request[:FromUserName]} click #{key}"
  end

  # When user views URL in the menu button
  on :view, with: 'http://weixin.somewhere.com/view_url' do |request, view|
    reply_text_message "#{request[:FromUserName]} view #{view}"
  end

  # When user sends an image
  on :image do |request|
    reply_image_message generate_image(request[:MediaId]) # Echo the sent image to user
  end

  # When user sends a voice
  on :voice do |request|
    reply_voice_message generate_voice(request[:MediaId]) # Echo the sent voice to user
  end

  # When user sends a video
  on :video do |request|
    reply_video_message generate_voice(request[:MediaId]) # Echo the sent video to user
  end

  # When user sends location message with label
  on :label_location do |request|
    reply_text_message("Label: #{request[:Label]} Location_X: #{request[:Location_X]} Location_Y: #{request[:Location_Y]} Scale: #{request[:Scale]}")
  end

  # When user sends location
  on :location do |request|
    reply_text_message("Latitude: #{request[:Latitude]} Longitude: #{request[:Longitude]} Precision: #{request[:Precision]}")
  end

  on :event, with: 'unsubscribe' do |request|
    reply_success_message # user can not receive this message
  end

  # When user enters the app / agent app
  on :event, with: 'enter_agent' do |request|
    reply_text_message "#{request[:FromUserName]} enter agent app now"
  end

  # When batch job "create/update user (incremental)" is finished.
  on :batch_job, with: 'sync_user' do |request, batch_job|
    reply_text_message "sync_user job #{batch_job[:JobId]} finished, return code #{batch_job[:ErrCode]}, return message #{batch_job[:ErrMsg]}"
  end

  # When batch job "replace user (full sync)" is finished.
  on :batch_job, with: 'replace_user' do |request, batch_job|
    reply_text_message "replace_user job #{batch_job[:JobId]} finished, return code #{batch_job[:ErrCode]}, return message #{batch_job[:ErrMsg]}"
  end

  # When batch job "invite user" is finished.
  on :batch_job, with: 'invite_user' do |request, batch_job|
    reply_text_message "invite_user job #{batch_job[:JobId]} finished, return code #{batch_job[:ErrCode]}, return message #{batch_job[:ErrMsg]}"
  end

  # When batch job "replace department (full sync)" is finished.
  on :batch_job, with: 'replace_party' do |request, batch_job|
    reply_text_message "replace_party job #{batch_job[:JobId]} finished, return code #{batch_job[:ErrCode]}, return message #{batch_job[:ErrMsg]}"
  end

  # mass sent job finish result notification
  on :event, with: 'masssendjobfinish' do |request|
    # https://mp.weixin.qq.com/wiki?action=doc&id=mp1481187827_i0l21&t=0.03571905015619936#8
    reply_success_message # request is XML result hash.
  end

  # If no match above will fallback to below
  on :fallback, respond: 'fallback message'
end
