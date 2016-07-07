require 'telegram/bot'
require_relative '../lib/assistant_base'
require_relative '../lib/db_manager'
require 'json'
require 'logger'

class TelegramAssistant < AssistantBase
  @db = DbManager.new
  def go
    $logger = Logger.new(File.dirname(__FILE__) + "/tg_#{@userid}_assistant.log")
    @cur_step = "start"
    next_steps :start, :addServer, :test
  end
  def receive
    subscribe('telegram')
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @assistant_message.pop
        unless msg_in.nil?
          $logger.debug msg_in
          case msg_in["message"]
            when '/test'
              $logger.debug "test matched. calling method!"
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
      end
    end
  end
  def test(data)
    valid_step? :test
    $logger.debug "test called. We are testing."
    next_steps :auth, :donate, :createUser
    begin
      btn_markup = Array.new
      buttons = ["New User", "Donate"]
      buttons.each do |btn|
        btn_markup << addButton(btn, 'test')
        $logger.debug "Current btn_markup Array: #{btn_markup}"
      end
      keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [%w(A B), %w(C D)], one_time_keyboard: true)
      #keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(inline_keyboard: btn_markup)
      publish(message: 'Bitte wählen!', chat_id: data["chat_id"], reply_markup: keyboard.to_compact_hash)
    rescue StandardError => e
      $logger.debug "Got Exception!"
      $logger.debug e
    end
  end
  def addServer(data)
    begin
      split_message = data["message"].split(' ')
      if split_message[5].nil?
        publish(message: "Missing parameter.\nSyntax is: /newServer <type> <url> <port> <username> [optional: password]", chat_id: data["chat_id"])
        publish(message: get_valid_servers, chat_id: data["chat_id"])
      else
        server_type = split_message[1]
        server_url = split_message[2]
        server_port = split_message[3]
        server_password = split_message[5]
        server_username = split_message[4]
        if @db.addServer(server_url, server_port, server_type, server_password, server_username)
          publish(message: "Server sucessfully added.", chat_id: data["chat_id"])
        end
      end
    rescue StandardError => e
      $logger.error "Error ocurred while creating new Server. Stacktrace follows"
      $logger.error e
    end
  end
  def addChannel(data)
    begin
      if @db.getServerCount(@userid) > 0
        #@db.addChannel(@userid, #serverid)
      else
        publish(message: @lang.get("no_server"), chat_id: data["chat_id"])
      end
    rescue StandardError => e
      $logger.error e
    end
  end
  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username)
    @db.addUser(username)
  end
  def addService

  end
  def listChannels(data)

  end
  def listServers(data)

  end
  def addButton(btn_text, callback)
    $logger.debug "Text for Button: #{btn_text}"
    Telegram::Bot::Types::KeyboardButton.new(text: btn_text, callback_data: callback)
  end
  #wir würgen den Assistenten ab wenn jemand einen falschen Schritt startet
  def wrongStep(data)
    $logger.error "User #{data["nick"]} hat den falschen Schritt gestartet. Angriff oder Bug. Bitte prüfen"
    publish(message: 'Da ging was schief. Der Schritt war hier nicht erlaubt! Zurück zum start.', chat_id: data["chat_id"])
    go
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
