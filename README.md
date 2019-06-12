# WeixinRailsMiddleware

[![Gem Version](https://badge.fury.io/rb/weixin_rails_middleware.png)](http://badge.fury.io/rb/weixin_rails_middleware)

This project rocks and uses MIT-LICENSE.

https://rubygems.org/gems/weixin_rails_middleware

**已经实现消息体签名及加解密，升级与使用，详见[Wiki 实现消息体签名及加解密](https://github.com/lanrion/weixin_rails_middleware/wiki/msg-encryption-decipher)**

## 微信企业版本

https://github.com/lanrion/qy_wechat

https://github.com/lanrion/qy_wechat_api

## 使用特别说明

### 支持Rails版本

已经支持 Rails 3, Rails 4

## 参考示例

Rails 4: https://github.com/lanrion/weixin_rails_middleware_example

Rails 3: https://github.com/lanrion/weixin_rails_3

### 相关gem推荐使用

* **微信高级功能** 请务必结合高级API实现：[weixin_authorize](https://github.com/lanrion/weixin_authorize)

* **Wap Ratchet 框架** 推荐使用： [twitter_ratchet_rails](https://github.com/lanrion/twitter_ratchet_rails)

## [查看 Wiki：](https://github.com/lanrion/weixin_rails_middleware/wiki)

* [Getting Start](https://github.com/lanrion/weixin_rails_middleware/wiki/Getting-Start)

* [实现自定义菜单](https://github.com/lanrion/weixin_rails_middleware/wiki/DIY-menu)

* [生成微信信息使用方法](https://github.com/lanrion/weixin_rails_middleware/wiki/Generate-message-helpers)

## 使用公司列表

如果您或者您的公司正在使用当中，欢迎加入此列表：

https://github.com/lanrion/weixin_rails_middleware/wiki/gem-users-list

## 实现功能

  * 自动验证微信请求。

  * 无需拼接XML格式，只需要使用 `ReplyWeixinMessageHelper` 辅助方法，即可快速回复。
    使用方法: ` render xml: reply_text_message("Your Message: #{current_message.Content}") `

  * 支持自定义token，适合一个用户使用。

  * 支持多用户token: 适合多用户注册网站，每个用户有不同的token，通过 `weixin_rails_middleware.rb` 配置好存储token的Model与字段名，即可。

  * 文本回复: `reply_text_message(content)`。

  * 音乐回复: `reply_music_message(music)`, `generate_music(title, desc, music_url, hq_music_url)`。

  * 图文回复: `reply_news_message(articles)`, `generate_article(title, desc, pic_url, link_url)`。

  * 视频回复: `reply_video_message(video)`。

  * 语音回复: `reply_voice_message(voice)`。

  * 图片回复: `reply_image_message(image)`。

  * 地理位置回复: 自定义需求。

  * 其他高级API实现：[weixin_authorize](https://github.com/lanrion/weixin_authorize)

## Responder Controller DSL

thanks [Eric-Guo/wechat](https://github.com/Eric-Guo/wechat)

为了在 app 中响应用户的消息，开发者需要创建一个 wexin responder controller. 首先在 router 中定义

```ruby
  resource :responder, only: [] do
    get  ':weixin_secret_key', action: :index
    post ':weixin_secret_key', action: :reply
  end
```

然后创建 Controller class, 例如

```ruby
# encoding: utf-8
# @params @weixin_message(request)   获取微信所有参数.
# @params @weixin_public_account     如果配置了 public_account_class 选项,则会返回当前实例,否则返回 nil
# @detail WeixinRailsMiddleware::Responder
# @thanks https://github.com/Eric-Guo/wechat
class ResponderController < ActionController::Base
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
    articles = 1.upto(count.to_i).map do |i|
      generate_article("News title - #{i}", "No. #{i} news content", 'http://www.baidu.com/img/bdlogo.gif', 'http://www.baidu.com/')
    end

    reply_news_message articles
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
```

## 如何测试？

  安装 [ngrok](https://ngrok.com)，解压后跑 `ngrok 4000`

  然后会产生以下信息：

  ```
  Tunnel Status                 online
  Version                       1.6/1.5
  Forwarding                    http://e0ede89.ngrok.com -> 127.0.0.1:4000
  Forwarding                    https://e0ede89.ngrok.com -> 127.0.0.1:4000
  Web Interface                 127.0.0.1:4040
  # Conn                        67
  Avg Conn Time                 839.50ms

  ```

 域名为 `http://e0ede89.ngrok.com`。 注意非付费版本域名每次会随机生成，不是固定的。


**Ngrok已墙，你懂得的**，ngrok 已墙，请使用localtunnel.me，使用方法：

`npm install -g localtunnel`
```sh
$ lt --port 8000
# your url is: https://gqgh.localtunnel.me
```

## 贡献你的代码

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`).
  3. Commit your changes (`git commit -am 'Add some feature'`).
  4. Push to the branch (`git push origin my-new-feature`).
  5. Create new Pull Request.
  6. Test with [weixin_rails_middleware_example](https://github.com/lanrion/weixin_rails_middleware_example), and push your changes.

## Bugs 和反馈

 如果你发现有出现任何的bug，请在 https://github.com/lanrion/weixin_rails_middleware/issues 记录你的bug详细信息，

 或者在 [Ruby China](http://ruby-china.org/) 开帖 [@ruby_sky](http://ruby-china.org/ruby_sky), 个人邮箱回复速度相对慢.

## 推荐阅读

  * [浅析微信信息信息接收与信息回复](https://gist.github.com/lanrion/9479631)

## 参考致谢
  在微信回复信息XML的封装方法，借鉴了 [rack-weixin](https://github.com/wolfg1969/rack-weixin) 实现，特此感谢！

## 捐赠支持

  如果你觉得我的gem对你有帮助，欢迎打赏支持，:smile:

  ![](https://raw.githubusercontent.com/lanrion/my_config/master/imagex/donation_me_wx.jpg)
