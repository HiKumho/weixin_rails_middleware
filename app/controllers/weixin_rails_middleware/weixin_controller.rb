module WeixinRailsMiddleware
  class WeixinController < ActionController::Base
    include WeixinRailsMiddleware::Responder
  end
end
