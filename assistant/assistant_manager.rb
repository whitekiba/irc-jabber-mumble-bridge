require 'childprocess'
require 'logger'
require 'redis'
require 'json'
require 'tempfile'
require_relative '../lib/db_manager'
require_relative '../lib/language'
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
    @redis_sub.psubscribe('assistant_all') do |on|
      on.psubscribe do |channel, subscriptions|
        $logger.info "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.pmessage do |pattern, channel, message|
        begin
          $logger.debug ("Got message! #{message}")
          sortMessage(message)
        rescue StandardError => e
          $logger.error e
        end
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
    $logger.info 'sortMessage called!'
    $logger.info parsed_message
    split_message = parsed_message['message'].split(' ')
    $logger.info "Split message: #{split_message}"
    #case wäre hier vermutlich sauberer. Aber wir brauchen das else
    if split_message[0].eql?('/auth') #auth ist der erste Schritt der nötig ist.

      #checken ob nötige parameter gesetzt sind
      if split_message[1].nil? || split_message[2].nil?
        publish(message: @lang.get("missing_parameter"), chat_id: parsed_message['chat_id'])
        publish(message: @lang.get("auth_usage"), chat_id: parsed_message['chat_id'])
        return #abwürgen
      end

      userid = @db.authUser(split_message[1], split_message[2])
      if userid
        publish(message: 'authenticated!', chat_id: parsed_message['chat_id'])
        begin
          @active_users[parsed_message['chat_id']] = userid
          $logger.info 'Starting new assistant'
          startNewAssistant(parsed_message['source_network'], @active_users[parsed_message['chat_id']])
        rescue StandardError => e
          $logger.error 'Error while starting assistant'
          $logger.error e
        end
      else
        publish(message: 'wrong username or password!', chat_id: parsed_message['chat_id'])
      end
    elsif split_message[0].eql?('/newUser') #user erstellen

      if split_message[1].nil?
        publish(message: @lang.get("missing_parameter"), chat_id: parsed_message['chat_id'])
        publish(message: @lang.get("new_user_usage"), chat_id: parsed_message['chat_id'])
      else #wir erstellen einen neuen User. Alle Parameter sind okay
        begin

          #wir checken den Usernamen
          if /^[a-z0-9_]+$/.match(split_message[1])
            secret = createUser(split_message[1], split_message[2]) #createUser handlet das falls split_message[2] nil ist
            if secret
              publish(message: @lang.get("user_created"), chat_id: parsed_message['chat_id'])
              publish(message: "#{@lang.get("your_secret")}: #{secret}", chat_id: parsed_message['chat_id'])
            end
          else
            publish(message: @lang.get("invalid_username"), chat_id: parsed_message['chat_id'])
          end

          #wir checken die Emailadresse (falls sie denn gesetzt wurde)
          if !split_message[2].nil?
            if !/\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/.match(split_message[2])
              publish(message: @lang.get("invalid_username"), chat_id: parsed_message['chat_id'])
              return #abwürgen um jeden Preis
            end
          end
        rescue StandardError => e
          publish(message: @lang.get("error_occured"), chat_id: parsed_message['chat_id'])
          $logger.error e
        end
      end

    elsif split_message[0].eql?('/start') || !split_message[0].initial.eql?('/')
      $logger.info '/start or non-command'
      begin
        aboutMe(parsed_message['chat_id'])
      rescue StandardError => e
        $logger.error e
      end
    else
      #TODO: Hier müssen wir noch etwas präziser bei den Fehlern werden.
      if @assistants["#{parsed_message['source_network']}_#{@active_users[parsed_message['chat_id']]}"].nil?
        publish(message: @lang.get('assistant_timeout'), chat_id: parsed_message['chat_id'])
      else
        #alles was nicht behandelt wurde wird an den Assistenten gepusht. Falls er denn läuft
        # hier kann nichts schlimmeres passieren. Läuft der Assistent nicht nimmt die nachricht ungefähr 150 byte ein
        @redis_pub.publish("assistant.#{@active_users[parsed_message['chat_id']]}", message)
      end
    end
  end

  def aboutMe(chat_id)
    publish(message: @lang.get('about_me'), chat_id: chat_id)
  end

  def startNewAssistant(protocol, userid)
    begin
      @assistants["#{protocol}_#{userid}"] = ChildProcess.build('ruby', "assistant/#{protocol}_assistant.rb", "#{userid}")
      @assistants["#{protocol}_#{userid}"].io.stdout = Tempfile.new("assistant_output_#{userid}.log")
      @assistants["#{protocol}_#{userid}"].start
      $logger.info 'Neuer Assistenzprozess gestartet'
    rescue StandardError => e
      $logger.error e
    end
  end

  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username = nil, email = nil)
    @db.addUser(username, email)
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