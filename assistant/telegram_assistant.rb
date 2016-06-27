require 'telegram/bot'
require_relative '../lib/assistant_base'
require_relative '../lib/db_manager'
require 'json'
class TelegramAssistant < AssistantBase
  @db = DbManager.new
  def go
    @cur_step = "start"
  end
  def receive
    subscribe('telegram')
    loop do
      sleep 0.1
    end
  end
  def start(data)
    next_steps :auth, :donate, :createUser
    buttons = ["New User", "Authenticate", "Donate"]
    publish(message: 'Bitte wählen!', chat_id: data["chat_id"])
  end
  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username = nil)

  end
  def addService

  end
  def addButton
    Telegram::Bot::Types::InlineKeyboardButton.new(text: btn_text, )
  end
end
ta = TelegramAssistant.new
ta.go
ta.receive
