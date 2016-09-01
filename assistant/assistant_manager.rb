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

    #TODO: Hier müssen wir noch etwas präziser bei den Fehlern werden.
    if @assistants["#{parsed_message['source_network']}_#{@active_users[parsed_message['chat_id']]}"].nil?
      case split_message[0]
        when '/auth'
          auth(split_message[1], split_message[2])
        when '/newUser'
          new_user(split_message[1], split_message[2])
        else
          aboutMe(parsed_message['chat_id'])
      end
    else
      #wir sind authentifiziert. Das handlet nun alles der assistant prozess
      @redis_pub.publish("assistant.#{@active_users[parsed_message['chat_id']]}", message)
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
  def create_user(username = nil, email = nil)

    #wir checken den Usernamen
    return @lang.get("invalid_username") unless /^[a-zA-Z0-9_]+$/.match(username)

    #wir checken die Emailadresse (falls sie denn gesetzt wurde)
    return @lang.get("invalid_email") unless /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/.match(email) unless email.nil?

    secret = @db.addUser(username, email)
    if secret
      return "#{@lang.get("user_created")}\n#{@lang.get("your_secret")}: #{secret}"
    end
  end
  private

  def new_user(username, email = nil)
    if username.nil?
      publish(message: @lang.get("missing_parameter"), chat_id: parsed_message['chat_id'])
      publish(message: @lang.get("new_user_usage"), chat_id: parsed_message['chat_id'])
    else #wir erstellen einen neuen User. Alle Parameter sind okay
      #User erstellen
      begin
        publish(message: create_user(username, email), chat_id: parsed_message['chat_id'])
      rescue StandardError => e
        publish(message: @lang.get("error_occured"), chat_id: parsed_message['chat_id'])
        $logger.error e
      end
    end
  end

  def auth(username, password)
    #checken ob nötige parameter gesetzt sind
    if username.nil? || password.nil?
      publish(message: @lang.get("missing_parameter"), chat_id: parsed_message['chat_id'])
      publish(message: @lang.get("auth_usage"), chat_id: parsed_message['chat_id'])
      return #abwürgen
    end

    userid = @db.authUser(username, password)
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
  end

  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    json = JSON.generate ({
        'message' => message,
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    @redis_pub.publish("assistant.#{@userid}", json)
  end
end

a = AssistantManager.new

a.subscribe
a.monitorAssistants