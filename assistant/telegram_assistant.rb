require 'telegram/bot'
require_relative '../lib/assistant_base'
require_relative '../lib/db_manager'
require 'json'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/tg_assistant.log')

class TelegramAssistant < AssistantBase
  @db = DbManager.new
  def go
    @cur_step = "start"
    next_steps :start
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
            when '/start'
              start(msg_in)
          end
        end
      end
    end
    loop do
      sleep 0.1
    end
  end
  def start(data)
    valid_step? :start
    $logger.debug "start called. We are starting."
    next_steps :auth, :donate, :createUser
    begin
      btn_markup = Array.new
      buttons = ["New User", "Authenticate", "Donate"]
      buttons.each do |btn|
        btn_markup << addButton(btn, 'test')
        $logger.debug "Current btn_markup Array: #{btn_markup}"
      end
      keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: btn_markup)
      publish(message: 'Bitte wählen!', chat_id: data["chat_id"], reply_markup: keyboard.to_compact_hash)
    rescue StandardError => e
      $logger.debug "Got Exception!"
      $logger.debug e
    end
  end
  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username = nil)

  end
  def addService

  end
  def addButton(btn_text, callback)
    $logger.debug "Text for Button: #{btn_text}"
    Telegram::Bot::Types::InlineKeyboardButton.new(text: btn_text, callback_data: callback)
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
