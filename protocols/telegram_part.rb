require 'telegram/bot'
require 'cgi'
require 'sanitize'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/telegram.log')

class TelegramBridge < ModuleBase
  @my_name = 'telegram'
  def receive
    $logger.info 'Telegram process starting...'
    @telegram = Telegram::Bot::Client.new($config[:token])

    subscribe(@my_name)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        if !msg_in.nil?
          $logger.info msg_in
          @telegram.api.send_message(chat_id: '-145447289', text: msg_in["message"])
        end
      end
    end
    @telegram.listen do |msg|
      sleep 0.1
      handleMessage(msg)
    end
  end

  def handleMessage(msg)
    #$logger.info 'handleMessage wurde aufgerufen!'
    #$logger.info msg.to_hash()
    unless msg.text.nil?
      publish(source_network_type: @my_name, source_user: 'empty', nick: msg.from.first_name, message: msg.text)
    end
  end
end

tg = TelegramBridge.new
tg.receive