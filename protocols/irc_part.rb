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

    @channels = @db.loadChannels(server_id)
    @channels_invert = @channels.invert
    $logger.debug @channels_invert
    $logger.debug "Starting Server. Credentials: #{server_url}, #{server_port}, #{server_username}"

    @bot = IRC.new(server_username, server_url, server_port, server_username)
    IRCEvent.add_callback('endofmotd') { |event| joinChannels }
    IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
    IRCEvent.add_callback('join') { |event| joinMessage event }
    IRCEvent.add_callback('part') { |event| partMessage event }
    IRCEvent.add_callback('quit') { |event| quitMessage event }

    subscribe(@my_name)
    subscribe_cmd(@my_id)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        unless msg_in.nil?
          $logger.info msg_in
          #user_id ist die zuordnungsnummer
          @bot.send_message(@channels_invert[msg_in['user_id']], "[#{msg_in['source_network_type']}][#{msg_in['nick']}]#{msg_in['message']}")
        end
      end
    end
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages_cmd.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        unless msg_in.nil?
          $logger.info msg_in
          command(msg_in['cmd'])
        end
      end
    end

    @bot.connect
  end

  def handleMessage(message)
    $logger.info 'handleMessage wurde aufgerufen'
    if /^\x01ACTION (.)+\x01$/.match(message.message)
      self.publish(source_network_type: @my_short,
                   message: " * [#{message.from}] #{message.message.gsub(/^\x01ACTION |\x01$/, '')}",
                   chat_id: '-145447289')
    else
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: message.from, message: message.message, user_id: @channels[message.channel])
    end
    $logger.info message.message
  end

  def joinMessage(event)
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: message.from, user_id: @channels[message.channel], message_type: 'join')
    end
  end

  def partMessage(event)
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: message.from, user_id: @channels[message.channel], message_type: 'part')
    end
  end

  def quitMessage(event)
    if event.from != @my_username
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: message.from, user_id: @channels[message.channel], message_type: 'quit')
    end
  end
  #Wir reloaden das Modul
  def reload
    $logger.info "Starting IRC reload."
    #Als erstes neue Channels
    @channels = @db.loadChannels(server_id)
    joinChannels #wir nutzen dafür die bestehende methode
  end

  def joinChannels
    $logger.info 'Got motd. Joining Channels.'
    @channels.each_key { | key |
      $logger.info 'Channel gejoint!'
      if !@bot.channels.include? key
        @bot.add_channel(key)
      end
    }
  end
end

#server starting stuff
#wir müssen für jeden Server eine eigene Instanz der IRCBridge erzeugen
db = DbManager.new
servers = db.loadServers('irc')
$logger.debug servers
servers.each do |server|
  #ich habe keine ahnung wieso da felder nil sind
  unless server.nil?
    Thread.new do
      begin
        irc = IRCBridge.new
        irc.receive(server['ID'], server['server_url'], server['server_port'], server['user_name'])
      rescue StandardError => e
        $logger.debug 'IRC crashed. Stacktrace follows.'
        $logger.debug e
      end
    end
  end
end

loop do
  sleep 0.1
end