require 'rubygems'
require 'IRC'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/irc.log')

class IRCBridge < ModuleBase
  def receive(server_id, server_url, server_port, server_username)
    @db = DbManager.new
    @my_name = 'irc'
    @my_username = server_username
    @my_short = 'I'
    @my_id = server_id

    loadSettings
    $logger.debug @channels_invert
    $logger.debug "Starting Server. Credentials: #{server_url}, #{server_port}, #{server_username}"

    @bot = IRC.new(server_username, server_url, server_port, server_username)
    IRCEvent.add_callback('endofmotd') { |event| joinChannels }
    IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
    IRCEvent.add_callback('join') { |event| joinMessage event }
    IRCEvent.add_callback('part') { |event| partMessage event }
    IRCEvent.add_callback('quit') { |event| quitMessage event }
    IRCEvent.add_callback('ping') { |event| gotPing event }


    subscribe(@my_name)
    subscribe_cmd(@my_id)
    Thread.new do
      loop do
        msg_in = @messages.pop
        unless msg_in.nil?
          begin
            $logger.info msg_in
            #user_id ist die zuordnungsnummer
            if msg_in["message_type"] == 'msg'
              @bot.send_message(@channels_invert[msg_in['user_id']],
                                "[#{msg_in['source_network_type']}][#{msg_in['nick']}] #{msg_in['message']}")
            else
              case msg_in["message_type"]
                when 'join'
                  @bot.send_message(@channels_invert[msg_in['user_id']],
                                    "#{msg_in["nick"]} kam in den Channel")
                when 'part'
                  @bot.send_message(@channels_invert[msg_in['user_id']],
                                    "#{msg_in["nick"]} hat den Channel verlassen")
                when 'quit'
                  @bot.send_message(@channels_invert[msg_in['user_id']],
                                    "#{msg_in["nick"]} hat den Server verlassen")
              end
            end
          rescue StandardError => e
            $logger.debug 'Failed to send message. Stacktrace:'
            $logger.debug e
          end
        end
      end
    end

    #pingchecker
    Thread.new do
      loop do
        waitForTimeout
        $logger.info "waitForTimeout ist durch. Wir brechen ab!"
        abort #sollte waitForTimeout irgendwie beenden aborten wir in der nächsten Zeile
      end
    end

    begin
      @bot.connect
    rescue StandardError => e
      $logger.debug 'Connect failed. Stacktrace follows.'
      $logger.debug e
      abort
    end
  end

  def handleMessage(message)
    gotPing(message)
    $logger.info 'handleMessage wurde aufgerufen'
    begin
      if /^\x01ACTION (.)+\x01$/.match(message.message)
        self.publish(source_network_type: @my_short, source_network: @my_name,
                     nick: message.from, message: " * [#{message.from}] #{message.message.gsub(/^\x01ACTION |\x01$/, '')}", user_id: @channels[message.channel])
      else
        self.publish(source_network_type: @my_short, source_network: @my_name,
                     nick: message.from, message: message.message, user_id: @channels[message.channel])
      end
      $logger.info message.message
    rescue StandardError => e
      $logger.error "Nachricht konnte nicht gesendet werden. Eventuell ist die Verbindung weg. Ich starte mal neu."
      $logger.error e
      abort #hart abwürgen
    end
  end

  def joinMessage(event)
    $logger.info "Join wurde aufgerufen."
    $logger.info event
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.from, user_id: @channels[event.channel], message_type: 'join')
    end
  end

  def partMessage(event)
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.from, user_id: @channels[event.channel], message_type: 'part')
    end
  end

  def quitMessage(event)
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: event.from, user_id: @channels[event.channel], message_type: 'quit')
    end
  end

  def gotPing(event)
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
    rescue StandardError => e
      $logger.error "Reloading failed. Exception thrown:"
      $logger.error e
    end
  end

  def joinChannels
    $logger.info 'Got motd. Joining Channels.'
    @channels.each_key { |key|
      if !@bot.channels.include? key
        $logger.info "Channel gejoint! (#{key})"
        @bot.add_channel(key)
      end
    }

    #wir verlassen channel die nicht existieren
    @bot.channels.each { |value|
      if !@channels.has_value?(value)
        @bot.part(value)
      end
    }
  end

  #diese Methode lädt settings aus der Datenbank und überschreibt bestehende
  #wird von reload und receive aufgerufen
  def loadSettings
    @channels = @db.loadChannels(@my_id)
    @channels_invert = @channels.invert
  end
end

$servers = Array.new

#server starting stuff
#wir müssen für jeden Server eine eigene Instanz der IRCBridge erzeugen
db = DbManager.new
#TODO: Wir müssen irgendwie neue Server starten. Vorerst pollen wir die Datenbank
#Ja das ist scheiße unschön.
#TODO: Unschön. Das muss sauberer umgesetzt werden. Alle 60 Sekunden die Datenbank anzufragen ist scheiße
#Es wäre möglich auf nem Redis Channel zu horchen und dann den reload zu triggern. Dafür müsste hier aber noch ein redis listener rein
loop do
  servers = db.loadServers('irc')
  $logger.debug servers
  servers.each do |server|
    #ich habe keine ahnung wieso da felder nil sind
    unless server.nil?
      if $servers[server['ID']].nil?
        begin
          Thread.new do
            $servers[server['ID']] = IRCBridge.new
            $servers[server['ID']].receive(server['ID'], server['server_url'], server['server_port'], server['user_name'])
          end
        rescue StandardError => e
          $logger.debug 'IRC crashed. Stacktrace follows.'
          $logger.debug e
        end
      end
    end
  end
  sleep 60 #60 sekunden sollte ausreichend häufig sein
end