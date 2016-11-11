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
    @timeout = 15 #das ist der timeout
    @timeout_warning = false

    @last_command = Time.now
    @next_step = Array.new

    @assistant_message = Queue.new
    @db = DbManager.new
    @chat_id = 0
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    @valid_servers = {'telegram' => 'Telegram',
                      'irc' => 'IRC',
                      'mumble' => 'Mumble',
                      'jabber' => 'Jabber'}
    @static_servers = [ 'telegram', 'irc' ]
  end

  def subscribe(name)
    $logger.debug "starting Subscribe Thread"
    begin
      Thread.new do
        sleep 0.1
        $logger.debug "Subscribing on assistant.#{@userid}"
        @redis_sub.psubscribe("assistant.#{@userid}") do |on|
          on.pmessage do |pattern, channel, message|
            data = JSON.parse(message)
            if data['source'] != "bot"
              resetTimeout
              #TODO: Code checken. Keine ahnung wofür das mal war
              #start(data) if data['source_network_type'].eql?(name) & data['message'].eql?('/start')
              $logger.debug "got message. unshifting the Queue"
              @assistant_message.push(data)
              $logger.debug("Length of @assistant_message #{@assistant_message.length}")
            end
          end
        end
      end
    rescue StandardError => e
      $logger.error "Exception beim subcriben auf Redis aufgetreten"
      $logger.error e
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
          publish(message: 'Invalid URL! Exiting hard!', chat_id: @chat_id)
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
            publish(message: @lang.get("invalid_username"), chat_id: @chat_id)
            return
          end
        end

        if @db.server_exists?(server_type, server_url, server_port)
          publish(message: @lang.get("server_already_exists"), chat_id: @chat_id)
        else
          if @db.addServer(server_url, server_port, server_type, server_password, server_username)
            publish(message: 'Server sucessfully added.', chat_id: @chat_id)
          end
        end

      else
        publish(message: 'You are not allowed to add a server of that type', chat_id: @chat_id)
      end
    rescue StandardError => e
      $logger.error 'Error ocurred while creating new Server. Stacktrace follows'
      $logger.error e
    end
  end

  def add_channel(server_id, channel_name)
    if server_id.nil? || channel_name.nil? #falls nil oder leer usage anzeigen
      publish(message: @lang.get("add_channel_usage"), chat_id: @chat_id)
      return
    end

    begin
      if @db.getServerCount(@userid) > 0

        #server_id checken ob es ne nummer ist
        unless server_id.is_a?(Fixnum)
          publish(message: @lang.get('invalid_id'), chat_id: @chat_id)
          return
        end

        if @db.channel_exists?(@userid, server_id, channel_name)
          publish(message: @lang.get("channel_already_exists"), chat_id: @chat_id)
        else
          if @db.getChannelCount(@user_id, server_id) > 1
            #TODO: Message anpassen
            publish(message: '1 Channel max.', chat_id: @chat_id)
          else
            if @db.addChannel(@userid, server_id, channel_name)
              publish(message: @lang.get("channel_added"), chat_id: @chat_id)
              reload(server_id)
            end
          end
        end
      else
        publish(message: @lang.get('no_server'), chat_id: @chat_id)
      end
    rescue StandardError => e
      $logger.error e
    end
  end

  def edit_server(server_id, server_url: nil, server_port: nil, server_username: nil, server_password: nil)
    if sever_id.nil? || server.nil? || server == '' #falls nil oder leer usage anzeigen
      publish(message: @lang.get("edit_server_usage"), chat_id: @chat_id)
      return
    end

    unless server_url.valid_url?
      publish(message: 'Invalid URL! Exiting hard!', chat_id: @chat_id)
      return
    end

    #username checken
    unless server_username.nil?
      $logger.info 'Setting server username to bridgie'
      server_username = 'bridgie'
    else
      unless /^[a-z0-9_]+$/.match(server_username)
        publish(message: @lang.get("invalid_username"), chat_id: @chat_id)
        return
      end
    end

    if @db.allowed_server?(server_id, @userid)
      @db.edit_server(server_id, server_url, server_port, server_username, server_password)
      reload(@db.get_server_type(server_id))
    end
  end

  def edit_channel(channel_id, channel_name)
    if channel_id.nil? || channel_name.nil? #falls nil oder leer usage anzeigen
      publish(message: @lang.get("edit_channel_usage"), chat_id: @chat_id)
      return
    end

    if @db.allowed_channel?(channel_id, @userid)
      @db.edit_channel(channel_id, channel_name)
      reload(@db.get_server_type_of_channel(channel_id))
    end
  end

  def help(unknown_command = false)
    if unknown_command
      publish(message: @lang.get('unknown_command'), chat_id: @chat_id)
    end
    publish(message: @lang.get('help_authenticated'), chat_id: @chat_id)
  end

  def logout
    publish(message: @lang.get('logging_out'), chat_id: @chat_id)
    exit
  end

  #Hier müssen wir zusehen dass wir das sehr gut sichern und alle Channel mitlöschen
  #
  def del_server(server_id)

    #server_id checken ob es ne nummer ist
    if !server_id.is_a?(Fixnum)
      publish(message: @lang.get('invalid_id'), chat_id: @chat_id)
      return
    end

    if @db.allowed_server?(server_id, @userid) #user darf das ding benutzen
      begin
        @db.loadChannels(server_id).each do |key, value|
          @db.del_channel(key)
        end
      rescue StandardError => e
        $logger.error "Fehler beim löschen! Schau dir die Exception an:"
        $logger.error e
        publish(message: @lang.get("unable_delete_channel"), chat_id: @chat_id)
        publish(message: @lang.get("unable_delete_server"), chat_id: @chat_id)
        return #wir würgen den aufruf der methode ab
      end
      server_type = @db.get_server_type(sever_id)
      @db.del_server(server_id)
      reload(server_type)
    end
  end

  def del_channel(channel_id)
    type  = @db.get_server_type_of_channel(channel_id)
    if @db.allowed_channel?(channel_id, @userid)
      @db.del_channel(channel_id)
      reload(type)
    end
  end

  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    $logger.debug "publish aufgerufen."
    json = JSON.generate ({
        'source' => 'bot',
        'message' => message.force_encoding('UTF-8'),
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    $logger.debug json
    @redis_pub.publish("assistant.#{@userid}", json)
  end

  def waitForTimeout
    loop do
      sleep 1
      if @last_command < (Time.now - ((@timeout-2)*60)) && !@timeout_warning
        publish(message: @lang.get('timeout_warning'), chat_id: @chat_id)
        @timeout_warning = true
      end
      if @last_command < (Time.now - (@timeout*60))
        publish(message: @lang.get('timed_out'), chat_id: @chat_id)
        break
      end
    end
  end

  def resetTimeout
    $logger.debug 'resetTimeout triggered. New time!'
    @timeout_warning = false
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
      available_server_text << "#{av_server['ID']} - #{av_server['server_url']} (#{av_server['server_type']})\n"
    end
    available_server_text
  end

  def get_channels(user_id)
    message = @lang.get('your_channels')
    @db.userChannels(user_id).each_value do |av_channel|
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

  def list_channels(data)
    begin
      publish(message: get_channels(@userid), chat_id: data['chat_id'])
    rescue StandardError => e
      $logger.error e
    end
  end

  def list_servers(data)
    $logger.debug "list_servers aufgerufen"
    publish(message: get_available_servers(@userid), chat_id: data['chat_id'])
  end
end


