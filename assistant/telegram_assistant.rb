require 'telegram/bot'
require_relative '../lib/assistant_base'
require 'json'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/telegram_assistant.log')
$logger.info 'test'
class TelegramAssistant < AssistantBase
  def receive
    subscribe('telegram')
   @telegram = Telegram::Bot::Client.new('216275672:AAGoqjZLStLGqFL54-bao5NwWeRdebyN4Ao')
    loop do
      sleep 0.1
    end
  end

  def start
    $logger.info 'hallo'
    @telegram.api.send_message(chat_id: '-145447289', text: 'Guten Tag')
  end
end

test = TelegramAssistant.new
test.receive
