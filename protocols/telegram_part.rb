require 'telegram/bot'
require 'cgi'
require 'sanitize'
class TelegramBridge
  def self.start(conf, bridge)
    if conf[:enabled] == false
      exit
    end
    @my_name = :telegram
    @conf = conf
    @bridge = bridge
    @telegram = Telegram::Bot::Client.new(@conf[:token])
    if @conf[:chatid].eql?('')
      puts "No chat id set! \nPlease add the bot to a chat now, to get the chat id of it!"
      loop do
        sleep 0.1
        @telegram.api.getUpdates(offset: -1, limit: 1)['result'].each do |data|
          begin
            update = Telegram::Bot::Types::Update.new(data)
            unless update.message.new_chat_participant.nil?
              if update.message.new_chat_participant.username.eql?(Telegram::Bot::Types::User.new(@telegram.api.getMe['result']).username)
                puts "Bot added to chat! \n Title: #{update.message.chat.title} \n Chat-ID: #{update.message.chat.id}"
                puts "Please exit and change your config now!"
                return
              end
            end
          rescue Exception => e
            $logger.log e
          end
        end
      end
    end
    @bridge.subscribe(@my_name)
    @bridge.addPrefix(@my_name, "T")
    Thread.new do
      loop do
        sleep 0.1
        if msg_in = bridge.getNextMessage(@my_name)
              @telegram.api.send_message(chat_id: @conf[:chatid], text: msg_in)
        end
      end
    end
    Thread.new do
      @telegram.listen do |msg|
        sleep 0.1
        handleMessage(msg)
      end
    end
  end

  def self.handleMessage(msg)
    $logger.info "handleMessage wurde aufgerufen!"
    $logger.debug msg.to_hash()
    unless msg.text.nil?
      unless msg.chat.id.to_s.eql? @conf[:chatid].to_s
        @telegram.api.send_message(chat_id: msg.chat.id, text: "Hey. Looks like you found the Fluxnet Bridge! Unfortunately you are not able to use it now. For further information check out: https://git.rout0r.org/fluxnet/bridge")
      else
        @bridge.broadcast(@my_name, "[#{msg.from.first_name}]: #{Sanitize.clean(CGI.unescapeHTML(msg.text))}")
      end
    end
  end
end

# vim: tabstop=3
