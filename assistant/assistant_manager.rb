require 'childprocess'
require 'logger'
require 'redis'
require 'json'
require 'tempfile'
require_relative "../lib/db_manager"
require_relative "../lib/language"
require_relative '../lib/base_helpers'

$logger = Logger.new(File.dirname(__FILE__) + '/assistant_manager.log')
class AssistantManager
  def initialize
    @lang = Language.new
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
        sortMessage(message)
      end
    end
  end

  def monitorAssistants
    loop do
      begin
        @assistants.each_key { |proc|
          #TODO: Der Code ist ungetestet. Ich hab keine Ahnung ob der funktioniert
          if @assistants[proc].exited?
            $logger.info "#{proc} exited. Removing it from all lists"
            @assistants[proc].stop
            userid = proc.split('_')[1]
            #TODO: Wir müssen den User aus der liste der aktiven user entfernen
            @assistants[proc] = nil #wir nillen den eintrag
            @active_users.delete(@active_users.invert[userid])
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
    parsed_message = JSON.parse(message)
    $logger.info "sortMessage called!"
    $logger.info parsed_message
    split_message = parsed_message["message"].split(' ')
    $logger.info "Split message: #{split_message}"
    #case wäre hier vermutlich sauberer. Aber wir brauchen das else
    if split_message[0].eql?("/auth") #auth ist der erste Schritt der nötig ist.
      userid = @db.authUser(split_message[1], split_message[2])
      if userid
        publish(message: "authenticated!", chat_id: parsed_message["chat_id"])
        begin
          @active_users[parsed_message["chat_id"]] = userid
          $logger.info "Starting new assistant"
          startNewAssistant(parsed_message["source_network"], @active_users[parsed_message["chat_id"]])
        rescue StandardError => e
          $logger.error "Error while starting assistant"
          $logger.error e
        end
      else
        publish(message: "wrong username or password!", chat_id: parsed_message["chat_id"])
      end
    elsif split_message[0].eql?("/start") || !split_message[0].initial.eql?("/")
      $logger.info "/start or non-command"
      begin
        aboutMe(parsed_message["chat_id"])
      rescue StandardError => e
        $logger.error e
      end
    else
      #TODO: Hier müssen wir noch etwas präziser bei den Fehlern werden.
      if @assistants["#{parsed_message["source_network"]}_#{@active_users[parsed_message["chat_id"]]}"].nil?
        publish(message: "assistant timed out. Please authenticate again.", chat_id: parsed_message["chat_id"])
      else
        @redis_pub.publish("assistant.#{@active_users[parsed_message["chat_id"]]}", message)
      end
    end
  end
  def aboutMe(chat_id)
    publish(message: @lang.get("about_me"), chat_id: chat_id)
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