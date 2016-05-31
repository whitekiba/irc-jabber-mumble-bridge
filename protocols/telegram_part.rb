require 'telegram/bot'
require 'cgi'
require 'sanitize'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/telegram.log')

class TelegramBridge < ModuleBase
  def receive
    @my_name = 'telegram'
    @my_short = 'T'
    $logger.info 'Telegram process starting...'
    @telegram = Telegram::Bot::Client.new('216275672:AAGoqjZLStLGqFL54-bao5NwWeRdebyN4Ao')
    subscribe(@my_name)
    subscribeAssistant(@my_name)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        if !msg_in.nil?
          $logger.info msg_in
          @telegram.api.send_message(chat_id: msg_in["chat_id"], text: msg_in["message"])
        end
      end
    end
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @assistantMessages.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        if !msg_in.nil?
          $logger.info msg_in
          kb = Array.new
          msg_in["buttons"].each do |btn|
            kb.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: btn, callback_data: btn))
          end
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
          @telegram.api.send_message(chat_id: msg_in["chat_id"], text: msg_in["message"], reply_markup: markup)
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
      is_assistant = false
      is_assistant = true if msg.chat.type.eql?('private')
      publish(source_network_type: @my_short, source_network: @my_name, source_user: 'empty', nick: msg.from.first_name, message: msg.text, is_assistant: is_assistant, chat_id: msg.chat.id)
    end
  end
end

tg = TelegramBridge.new
tg.receive