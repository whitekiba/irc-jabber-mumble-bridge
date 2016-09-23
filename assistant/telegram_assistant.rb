require 'telegram/bot'
require_relative '../lib/assistant_base'
require 'json'
require 'logger'

class TelegramAssistant < AssistantBase
  def go
    $logger = Logger.new(File.dirname(__FILE__) + "/tg_#{@userid}_assistant.log")
    @cur_step = 'start'
    next_steps :start, :addServer, :test
  end

  def receive
    subscribe('telegram')
    Thread.new do
      loop do
        begin
          msg_in = @assistant_message.pop
          unless msg_in.nil?
            $logger.debug 'assistant got message. handling it!'
            $logger.debug msg_in
            split_message = msg_in['message'].split(' ')
            $logger.debug split_message
            @chat_id = msg_in['chat_id']
            case split_message[0]
              when '/test'
                $logger.debug 'test matched. calling method!'
                test(msg_in)
              when '/addServer', '/newServer'
                addServer(split_message[1], split_message[2], split_message[3], split_message[4], split_message[5])
              when '/addChannel', '/newChannel'
                add_channel(split_message[1], split_message[2])
              when '/showChannels', '/listChannels'
                list_channels(msg_in)
              when '/showServers', '/listServers'
                list_servers(msg_in)
              when '/editServer'
                edit_server(split_message[1], split_message[2], split_message[3], split_message[4], split_message[5])
              when '/editChannel'
                edit_channel(split_message[1], split_message[2]) #1 ist channel id, 2 ist channel name
            end
          end
        rescue StandardError => e
          logger.debug 'Exception'
          $logger.error e
        end
      end
    end
  end

  #TODO: Das muss eventuell entfernt oder deaktiviert werden
  def test(data)
    valid_step? :test
    $logger.debug 'test called. We are testing.'
    next_steps :auth, :donate, :create_user
    begin
      btn_markup = Array.new
      buttons = ['New User', 'Donate']
      buttons.each do |btn|
        btn_markup << addButton(btn, 'test')
        $logger.debug "Current btn_markup Array: #{btn_markup}"
      end
      keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(A B), %w(C D)], one_time_keyboard: true)
      #keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(inline_keyboard: btn_markup)
      publish(message: 'Bitte wählen!', chat_id: data['chat_id'], reply_markup: keyboard.to_compact_hash)
    rescue StandardError => e
      $logger.debug 'Got Exception!'
      $logger.debug e
    end
  end

  def addButton(btn_text, callback)
    $logger.debug "Text for Button: #{btn_text}"
    Telegram::Bot::Types::KeyboardButton.new(text: btn_text, callback_data: callback)
  end
  private

  #nur ein alias für go um wieder an den anfang zu kommen
  def reset
    go
  end
end
ta = TelegramAssistant.new
ta.go
ta.receive
ta.waitForTimeout
