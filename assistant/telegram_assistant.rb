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
        sleep 0.1
        begin
          msg_in = @assistant_message.pop
          unless msg_in.nil?
            $logger.debug 'assistant got message. handling it!'
            $logger.debug msg_in
            split_message = msg_in['message'].split(' ')
            $logger.debug split_message
            case split_message[0]
              when '/test'
                $logger.debug 'test matched. calling method!'
                test(msg_in)
              when '/addServer', '/newServer'
                addServer(msg_in)
              when '/addChannel', '/newChannel'
                addChannel(msg_in)
              when '/showChannels', '/listChannels'
                listChannels(msg_in)
              when '/showServers', '/listServers'
                listServers(msg_in)
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
    next_steps :auth, :donate, :createUser
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

  def addServer(data)
    $logger.debug "We are in addServer. My data is #{data}"
    begin
      split_message = data['message'].split(' ')
      $logger.debug "Field 4 is: #{split_message[4]}"
      if split_message[4].nil?
        publish(message: @lang.get("mssing_parameter"), chat_id: data['chat_id'])
        publish(message: @lang.get("add_server_usage"), chat_id: data['chat_id'])
        publish(message: get_valid_servers, chat_id: data['chat_id'])
      else
        $logger.debug split_message
        server_type = split_message[1] #server type
        #Wir checken ob server_type ein fester typ ist welchen wir intern nutzen
        # oooooder aber ob server_type überhaupt ein erlaubter Server ist
        if !@static_servers.has_value?(server_type) && @valid_servers.has_value?(server_type)
          split_message[2].valid_url? ?
              server_url = split_message[2] :
              publish(message: 'Invalid URL! Exiting hard!', chat_id: data['chat_id'])
          server_port = split_message[3] #server port
          unless split_message[5].nil?
            $logger.info 'Setting server password to nil'
            server_password = nil
          else
            server_password = split_message[5]
          end
          unless split_message[4].nil?
            $logger.info 'Setting server username to bridgie'
            server_username = 'bridgie'
          else
            server_username = split_message[4]
          end
          if @db.server_exists?(server_type, server_url, server_port)
            publish(message: @lang.get("server_already_exists"), chat_id: data['chat_id'])
          else
            if @db.addServer(server_url, server_port, server_type, server_password, server_username)
              publish(message: 'Server sucessfully added.', chat_id: data['chat_id'])
            end
          end
        else
          publish(message: 'You are not allowed to add a server of that type', chat_id: data['chat_id'])
        end
      end
    rescue StandardError => e
      $logger.error 'Error ocurred while creating new Server. Stacktrace follows'
      $logger.error e
    end
  end

  def addChannel(data)
    begin
      split_message = data['message'].split(' ')
      if split_message[2].nil?
        publish(message: @lang.get("mssing_parameter"), chat_id: data['chat_id'])
        publish(message: @lang.get("add_channel_usage"), chat_id: data['chat_id'])
        publish(message: get_available_servers(@userid), chat_id: data['chat_id'])
      else
        if @db.getServerCount(@userid) > 0
          server_id = split_message[1]
          channel_name = split_message[2]
          if @db.channel_exists?(@userid, server_id, channel_name)
            publish(message: @lang.get("channel_already_exists"), chat_id: data['chat_id'])
          else
            if @db.getChannelCount(@user_id, server_id) > 1
              #TODO: Message anpassen
              publish(message: '1 Channel max.', chat_id: data['chat_id'])
            else
              if @db.addChannel(@userid, server_id, channel_name)
                publish(message: @lang.get("channel_added"), chat_id: data['chat_id'])
                reload(server_id)
              end
            end
          end
        else
          publish(message: @lang.get('no_server'), chat_id: data['chat_id'])
        end
      end
    rescue StandardError => e
      $logger.error e
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
