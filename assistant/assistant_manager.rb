require 'childprocess'
require 'logger'
require 'redis'
require 'json'
require 'tempfile'
require_relative "../lib/db_manager"

$logger = Logger.new(File.dirname(__FILE__) + '/assistant_manager.log')
class AssistantManager
  def initialize
    @active_users = Hash.new
    @db = DbManager.new
    @assistants = Hash.new
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
  end
  def subscribe
    @redis_sub.psubscribe("assistant_all") do |on|
      on.psubscribe do |channel, subscriptions|
        $logger.info "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.pmessage do |pattern, channel, message|
        $logger.debug ("Got message! #{message}")
        sortMessage(JSON.parse(message))
      end
    end
  end

  def monitorAssistants
    loop do
      begin
        @assistants.each_key { |proc|
          if @assistants[proc].exited?
            @assistants[proc].stop
            userid = proc.split('_')[1]
            #TODO: Wir müssen den User aus der liste der aktiven user entfernen
            @assistants[proc] = nil #wir nillen den eintrag
            puts "#{proc} exited. Thats all we know."
          end
        }
        sleep 1
      rescue StandardError => e
        $logger.error e
      end
    end
  end
  def sortMessage(message)
    $logger.info "sortMessage called!"
    $logger.info message
    split_message = message["message"].split(' ')
    $logger.info "Split message: #{split_message}"
    if split_message[0].eql?("/auth")
      userid = @db.authUser(split_message[1], split_message[2])
      if userid
        publish(message: "authenticated!", chat_id: message["chat_id"])
        begin
          @active_users[message["chat_id"]] = userid
          $logger.info "Starting new assistant"
          startNewAssistant(message["source_network"], @active_users[message["chat_id"]])
        rescue StandardError => e
          $logger.error "Error while starting assistant"
          $logger.error e
        end
      else
        publish(message: "wrong username or password!", chat_id: message["chat_id"])
      end
    else
      if @assistants["#{message["source_network"]}_#{@active_users[message["chat_id"]]}"].nil?
        publish(message: "assistant timed out. Please authenticate again.", chat_id: message["chat_id"])
      else
        #hier publishen wir auf dem Ziel
        #TODO: Fehlt bisher noch
      end
    end
  end
  def startNewAssistant(protocol, userid)
    @assistants["#{protocol}_#{userid}"] = ChildProcess.build('ruby', "assistant/#{protocol}_assistant.rb", "#{userid}")
    @assistants["#{protocol}_#{userid}"].io.stdout = Tempfile.new("assistant_output_#{userid}.log")
    @assistants["#{protocol}_#{userid}"].start
  end
  private
  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    json = JSON.generate ({
        'message' => message,
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    @redis_pub.publish("assistant.#{@userid}", json)
    puts json
  end
end

a = AssistantManager.new

a.subscribe
a.monitorAssistants