require 'telegram/bot'
require 'cgi'
require 'sanitize'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/telegram.log')

class TelegramBridge < ModuleBase
  def receive
    @my_name = 'telegram'
    @my_short = 'T'
    @my_id = 3
    $logger.info 'Telegram process starting...'
    @telegram = Telegram::Bot::Client.new($config[:telegram][:token])
    @db = DbManager.new

    @chat_ids = @db.loadChannels(@my_id)
    @chat_ids_invert = @chat_ids.invert

    subscribe(@my_name)
    subscribeAssistant(@my_name)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        #$logger.debug("Length of @message seen by #{@my_name}: #{@messages.length}")
        if !msg_in.nil?
          $logger.info msg_in
          begin
            @telegram.api.send_message(chat_id: @chat_ids_invert[msg_in["user_id"]],
                                       text: "[#{msg_in["source_network_type"]}][#{msg_in["nick"]}] #{msg_in["message"]}")
          rescue StandardError => e
            $logger.error e
          end
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
    $logger.info msg.to_hash()
    unless msg.new_chat_member.nil?
      if msg.from.first_name == "bridge"
        @telegram.api.send_message(chat_id: msg.chat.id, text: "Ohai. I am new. This chat has ID: #{msg.chat.id}")
      end
    end
    unless msg.text.nil?
      is_assistant = false
      is_assistant = true if msg.chat.type.eql?('private')
      publish(source_network_type: @my_short,
              user_id: @chat_ids[msg.chat.id.to_s],
              source_network: @my_name, source_user: 'empty',
              nick: msg.from.first_name, message: msg.text,
              is_assistant: is_assistant, chat_id: msg.chat.id)
    end
  end
end

tg = TelegramBridge.new
tg.receive