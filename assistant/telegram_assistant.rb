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
            when '/addServer'
              addServer(msg_in)
          end
        end
      end
    end
  end
  def test(data)
    valid_step? :test
    $logger.debug "test called. We are starting."
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

  end
  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username = nil)

  end
  def addService

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
