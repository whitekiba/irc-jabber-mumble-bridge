require 'redis'
require 'json'
require 'uri'
require_relative 'language'
require_relative '../lib/db_manager'

class AssistantBase
  def initialize
    if !ARGV[0].nil?
      @userid = ARGV[0]
    else
      puts "Keine User ID. Ende!"
      exit
    end
    @lang = Language.new
    @timeout = 1 #das ist der timeout

    @last_command = Time.now
    @next_step = Array.new
    @assistant_message = Array.new
    @db = DbManager.new
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    @valid_servers = {'telegram' => 'Telegram',
                      'irc' => 'IRC',
                      'mumble' => 'Mumble',
                      'jabber' => 'Jabber'}
    @static_servers = [ 'telegram', 'irc' ]
  end

  def subscribe(name)
    Thread.new do
      sleep 0.1
      @redis_sub.psubscribe("assistant.#{@userid}") do |on|
        on.pmessage do |pattern, channel, message|
          data = JSON.parse(message)
          resetTimeout
          #TODO: Code checken. Keine ahnung wofür das mal war
          #start(data) if data['source_network_type'].eql?(name) & data['message'].eql?('/start')
          @assistant_message.unshift(data)
        end
      end
    end
  end

  def add_server(server_type, server_url, server_port, server_username = nil, server_password = nil)
    $logger.debug "We are in addServer. My data is #{data}"
    begin
      #Wir checken ob server_type ein fester typ ist welchen wir intern nutzen
      # oooooder aber ob server_type überhaupt ein erlaubter Server ist
      if !@static_servers.has_value?(server_type) && @valid_servers.has_value?(server_type)

        #url validieren
        unless server_url.valid_url?
          publish(message: 'Invalid URL! Exiting hard!', chat_id: data['chat_id'])
          return
        end

        #server passwort checken
        unless server_password.nil?
          $logger.info 'Setting server password to nil'
          server_password = nil
        end

        #username checken
        unless server_username.nil?
          $logger.info 'Setting server username to bridgie'
          server_username = 'bridgie'
        else
          unless /^[a-z0-9_]+$/.match(server_username)
            publish(message: @lang.get("invalid_username"), chat_id: data['chat_id'])
            return
          end
        end

        if @db.server_exists?(server_type, server_url, server_port)
          publish(message: @lang.get("server_already_exists"), chat_id: data['chat_id'])
        else
          if @db.addServer(server_url, server_port, server_type, server_password, server_username)
            publish(message: 'Server sucessfully added.', chat_id: data['chat_id'])
          end
        end

      else
        publish(message: 'You are not allowed to add a server of that type', chat_id: data['chat_id'])
      end
    rescue StandardError => e
      $logger.error 'Error ocurred while creating new Server. Stacktrace follows'
      $logger.error e
    end
  end

  def add_channel(server_id, channel_name)
    begin
      if @db.getServerCount(@userid) > 0

        #server_id checken ob es ne nummer ist
        if !server_id.is_a?(Fixnum)
          publish(message: @lang.get('invalid_id'), chat_id: data['chat_id'])
          return
        end

        if @db.channel_exists?(@userid, server_id, channel_name)
          publish(message: @lang.get("channel_already_exists"), chat_id: data['chat_id'])
        else
          if @db.getChannelCount(@user_id, server_id) > 1
            #TODO: Message anpassen
            publish(message: '1 Channel max.', chat_id: data['chat_id'])
          else
            if @db.addChannel(@userid, server_id, channel_name)
              publish(message: @lang.get("channel_added"), chat_id: data['chat_id'])
              reload(server_id)
            end
          end
        end
      else
        publish(message: @lang.get('no_server'), chat_id: data['chat_id'])
      end
    rescue StandardError => e
      $logger.error e
    end
  end

  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    json = JSON.generate ({
        'message' => message.force_encoding('UTF-8'),
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    @redis_pub.publish("assistant.#{@userid}", json)
  end

  def waitForTimeout
    loop do
      sleep 1
      break if @last_command < (Time.now - (@timeout*60)) #5 ist der timeout
    end
  end

  def resetTimeout
    $logger.debug 'resetTimeout triggered. New time!'
    @last_command = Time.now
  end

  def valid_step?(step)
    unless @next_step.index(step).nil?
      true
    end
    false
  end

  def next_steps(*args)
    @next_step.clear
    args.each do |arg|
      @next_step << arg
    end
  end

  def validate_parameters(*args)

  end

  def is_valid_server?(server)
    if @valid_servers.key?(server)
      true
    end
  end

  def get_available_servers(user_id)
    available_server_text = @lang.get('available_server_intro')
    @db.userServers(user_id).each_value do |av_server|
      available_server_text << "#{av_server['ID']} - #{av_server['server_url']}\n"
    end
    available_server_text
  end

  def get_channels(user_id)
    message = @lang.get('your_channels')
    @db.userChannels(user_ID).each_value do |av_channel|
      message << "#{av_channel['ID']} - #{av_channel['channel_name']}\n"
    end
    message
  end

  def get_valid_servers
    valid_server_text = @lang.get('valid_server_intro')
    @valid_servers.each_value do |server|
      valid_server_text << "- #{server}\n"
    end
    valid_server_text
  end

  def send_command(target, command)
    if @db.valid_server?(target)
      @redis_pub.publish("cmd.#{target}", command)
    end
  end

  def reload(target)
    send_command(target, "reload")
  end

  def start_new_servers(type)
    #TODO: Da wir die Multiserver funktion noch nicht ganz stabil haben muss das noch geschrieben werden
    #hier sollte ein command kommen welches den core anweist neue Server zu starten
    #parameter sind noch nicht klar, einbindung ist noch nicht klar
  end

  #wir würgen den Assistenten ab wenn jemand einen falschen Schritt startet
  def wrongStep(data)
    $logger.error "User #{data['nick']} hat den falschen Schritt gestartet. Angriff oder Bug. Bitte prüfen"
    publish(message: 'Da ging was schief. Der Schritt war hier nicht erlaubt! Zurück zum start.', chat_id: data['chat_id'])
    go
  end

  #user erstellen
  #solang user nil ist werden die buttons gesendet
  def createUser(username)
    @db.addUser(username)
  end

  def listChannels(data)
    begin
      publish(message: get_channels(@userid), chat_id: data['chat_id'])
    rescue StandardError => e
      $logger.error e
    end
  end

  def listServers(data)
    publish(message: get_available_servers(@userid), chat_id: data['chat_id'])
  end
end


