require 'rubygems'
require 'cinch'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/irc.log')
$logger.level = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:loglevel]

class IRCBridgeBotStart
  def receive(server_id, server_url, server_port, server_username)
    $logger.debug "Starting Server. My ID: #{server_id} Credentials: #{server_url}, #{server_port}, #{server_username}"

    @db = DbManager.new
    channels_array = Array.new

    channels = @db.loadChannels(server_id).dup
    channels.each_pair { |key, value|
      channels_array.push key
    }

    @bot = Cinch::Bot.new do
      configure do |c|
        c.server = server_url
        c.port = server_port
        c.nick = server_username
        c.user = server_username
        c.realname = "Bot! Admin: WhiteKIBA"
        c.channels = channels_array
        c.plugins.plugins = [IRCBridge]
        c.shared = {"server_id" => server_id, "server_username" => server_username}
      end

    end

    begin
      @bot.start
    rescue StandardError => e
      $logger.debug "Connect failed for #{@my_id}. Stacktrace follows."
      $logger.debug e
      abort
    end

    loop do
      sleep 60
    end
  end
end

class IRCBridge < ModuleBase
  include Cinch::Plugin
  attr_accessor :my_id, :my_username

  def initialize(*args)
    super
    setup_base

    @my_name = 'irc'
    @my_username = shared["server_username"]
    @my_short = 'I'
    @my_id = shared["server_id"]
    @@channels = Hash.new


    loadSettings

    $logger.debug "Object ID of channels inside initialize: #{@@channels.object_id}"
    $logger.debug @channels_invert

    subscribe(@my_name)
    subscribe_cmd(@my_id)
    Thread.new do
      loop do
        msg_in = @messages.pop
        unless msg_in.nil?
          if @channels_invert.count > 0
            begin
              $logger.info msg_in
              #user_id ist die zuordnungsnummer
              if msg_in["message_type"] == 'msg'
                Channel(@channels_invert[msg_in['user_id']])
                    .send("[#{msg_in['source_network_type']}][#{msg_in['nick']}] #{msg_in['message']}")
              else
                case msg_in["message_type"]
                  when 'join'
                    Channel(@channels_invert[msg_in['user_id']])
                        .send("#{msg_in["nick"]} kam in den Channel")
                  when 'part'
                    Channel(@channels_invert[msg_in['user_id']])
                        .send("#{msg_in["nick"]} hat den Channel verlassen")
                  when 'quit'
                    Channel(@channels_invert[msg_in['user_id']])
                        .send("#{msg_in["nick"]} hat den Server verlassen")
                end
              end
            rescue StandardError => e
              $logger.debug 'Failed to send message. Stacktrace:'
              $logger.debug e
            end
          end
        end
      end
    end

    #pingchecker
    #das ist nötig um eventuelle verbindungsabbrüche vernünftig erkennen zu können
    Thread.new do
      loop do
        waitForTimeout
        $logger.info "waitForTimeout ist durch. Wir brechen ab!"
        abort #sollte waitForTimeout irgendwie beenden aborten wir in der nächsten Zeile
      end
    end

    Thread.new do
      keep_username
    end
  end

  listen_to :privmsg, method: :handle_message
  def handle_message(message)
    got_ping(message)
    $logger.info 'handleMessage wurde aufgerufen'
    $logger.debug message
    $logger.debug 'My channels!'
    $logger.debug @@channels
    $logger.debug "Object ID of channels inside handleMessage: #{@@channels.object_id}"
    begin
      if /^\x01ACTION (.)+\x01$/.match(message.message)
        self.publish(source_network_type: @my_short, source_network: @my_name,
                     nick: message.user, message: " * [#{message.user}] #{message.message.gsub(/^\x01ACTION |\x01$/, '')}", user_id: @@channels[message.channel])
      else
        self.publish(source_network_type: @my_short, source_network: @my_name,
                     nick: message.user, message: message.message, user_id: @@channels[message.channel])
      end
      $logger.info message.message
    rescue StandardError => e
      $logger.error "Nachricht konnte nicht gesendet werden. Eventuell ist die Verbindung weg. Ich starte mal neu."
      $logger.error e
      abort #hart abwürgen
    end
  end

  listen_to :join, method: :join_message
  def join_message(event)
    $logger.info "Join wurde aufgerufen."
    $logger.info event
    if event.user != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.user, user_id: @@channels[event.channel], message_type: 'join')
    end
  end

  listen_to :part, method: :part_message
  def part_message(event)
    if event.user != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.user, user_id: @@channels[event.channel], message_type: 'part')
    end
  end

  listen_to :quit, method: :quit_message
  def quit_message(event)
    if event.user != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.user, user_id: @@channels[event.channel], message_type: 'quit')
    end
  end

  listen_to :pong, method: :got_ping
  def got_ping(event)
    $logger.info "Ping!"
    $logger.debug 'resetTimeout triggered. New time!'
    @last_ping = Time.now
  end

  #Wir reloaden das Modul
  def reload
    begin
      $logger.info "Starting IRC reload."
      #Als erstes neue Channels
      loadSettings
      joinChannels #wir nutzen dafür die bestehende methode
      @blacklist.reload
    rescue StandardError => e
      $logger.error "Reloading failed. Exception thrown:"
      $logger.error e
    end
  end

  def joinChannels
    $logger.info 'Got motd. Joining Channels.'
    $logger.debug @@channels
    @@channels.each_key { |key|
      if !@bot.channels.include? key
        $logger.info "Channel gejoint! (#{key})"
        @bot.join(key)
      end
    }

    #wir verlassen channel die nicht existieren
    @bot.channels.each { |value|
      if !@@channels.has_value?(value)
        @bot.part(value)
      end
    }
  end

  def keep_username
    loop do
      sleep 60

      if @bot.nick != @bot_username
        @bot.set_nick(@bot_username)
      end
    end
  end

end

$servers = Hash.new

#server starting stuff
#wir müssen für jeden Server eine eigene Instanz der IRCBridge erzeugen
db = DbManager.new
#TODO: Wir müssen irgendwie neue Server starten. Vorerst pollen wir die Datenbank
#Ja das ist scheiße unschön.
#TODO: Unschön. Das muss sauberer umgesetzt werden. Alle 60 Sekunden die Datenbank anzufragen ist scheiße
#Es wäre möglich auf nem Redis Channel zu horchen und dann den reload zu triggern. Dafür müsste hier aber noch ein redis listener rein
if !ARGV[0].nil?
      server_id = ARGV[0]
      begin
        server = db.load_server(server_id)
        srv = IRCBridgeBotStart.new
        srv.receive(server['ID'], server['server_url'], server['server_port'], server['user_name'])
      rescue StandardError => e
        $logger.debug 'IRC crashed. Stacktrace follows.'
        $logger.debug e
      end
else
  loop do
    servers = db.loadServers('irc')
    $logger.debug servers
    servers.each do |server|
      #ich habe keine ahnung wieso da felder nil sind
      unless server.nil?
        if $servers[server['ID']].respond_to?(:exited?)
          if $servers[server['ID']].exited?
            $servers[server['ID']] = nil #nil setzen damit die gb das ding entfernt
          end
        else
          $servers[server['ID']] = ChildProcess.build('ruby', "protocols/irc_part.rb", "#{server["ID"]}")
          $servers[server['ID']].start
        end
      end
      #$logger.debug $servers
      sleep 3
    end
    sleep 60 #60 sekunden sollte ausreichend häufig sein
  end
end