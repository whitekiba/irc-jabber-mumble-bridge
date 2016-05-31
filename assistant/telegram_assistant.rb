require 'telegram/bot'
require_relative '../lib/assistant_base'
require 'json'
class TelegramAssistant < AssistantBase
  def receive
    subscribe('telegram')
    loop do
      sleep 0.1
    end
  end
  def start(data)
    buttons = ["Test1", "Test2", "Test3"]
    publish(message: 'Bitte wählen!', chat_id: data["chat_id"], buttons: buttons)
  end
end
ta = TelegramAssistant.new
ta.receive
