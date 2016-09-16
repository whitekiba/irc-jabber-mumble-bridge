require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc/helper/simplemucclient'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'

$logger = Logger.new(File.dirname(__FILE__) + '/jabber.log')

class JabberBridge < ModuleBase
  def startServer(id, address, port, username, password)
    @my_name = 'jabber'
    @my_short = 'J'
    @my_id = id
    @db = DbManager.new
    $logger.info 'New Jabber Server started.'
    $logger.debug "My credentials are: Username: #{username} and Password: #{password}"
    @muc = Hash.new

    begin
      @jid = Jabber::JID.new(username)
      @bot = Jabber::Client.new(@jid)
      @bot.connect
      $logger.info 'Connected to server.'
      @bot.auth(password)
    rescue StandardError => e
      $logger.info e
    end

    #subscribe stuff
    subscribe(@my_name)
    subscribe_cmd(@my_name)
    Thread.new do
      loop do
        msg_in = @messages.pop
        if !msg_in.nil?
          $logger.debug msg_in
          begin
            if msg_in["message_type"] == 'msg'
              @muc[@channels_invert[msg_in['user_id']]]
                  .say("[#{msg_in['source_network_type']}][#{msg_in['nick']}] #{msg_in['message']}")
            else
              case msg_in["message_type"]
                when 'join'
                  @muc[@channels_invert[msg_in['user_id']]]
                      .say("#{msg_in["nick"]} kam in den Channel")
                when 'part'
                  @muc[@channels_invert[msg_in['user_id']]]
                      .say("#{msg_in["nick"]} hat den Channel verlassen")
                when 'quit'
                  @muc[@channels_invert[msg_in['user_id']]]
                      .say("#{msg_in["nick"]} hat den Server verlassen")
              end
            end
          rescue StandardError => e
            $logger.error 'Unable to send message. Stacktrace follows:'
            $logger.error e
          end
        end
      end
    end
    #cmd thread
    Thread.new do
      loop do
        msg_in = @messages.pop
        if !msg_in.nil?
            if msg_in['cmd'] == 'reload'
              reload
            end
        end
      end
    end
    loop do
      sleep 60
    end
  end

  def handleMessage(nick, channel, message)
    $logger.debug 'handleMessage called.'
    $logger.debug message
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, message: message, user_id: @channels[channel])
  end
  def handleJoin(nick)
    $logger.debug 'handleJoin called.'
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, user_id: @channels[channel], message_type: 'join')
  end
  def handleLeave(nick)
    $logger.debug 'handleLeave called.'
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, user_id: @channels[channel], message_type: 'part')
  end

  def join_channels
    @channels = @db.loadChannels(@my_id)
    $logger.debug @channels
    #wird genutzt für die channel zu user zuordnung. channel name => user id
    @channels_invert = @channels.invert

    #wir schreiben unsere Channel in den @muc hash.
    $logger.debug @channels_invert
    @channels_invert.each_value do |channel|
      join_channel(channel)
    end
  end

  def join_channel(channel)
    $logger.info "Joining MUC #{channel}"
    begin
      unless @muc[channel].nil?
        @muc[channel] = Jabber::MUC::SimpleMUCClient.new(@bot)
        @muc[channel].join(channel)
        @muc[channel].on_message { |time,nick,text|
          unless time
            if nick != 'bridge'
              handleMessage(nick, channel, text)
            end
          end
        }
        @muc[channel].on_join { |time, nick| handleJoin(nick) }
        @muc[channel].on_leave { |time, nick| handleLeave(nick) }
      end
    rescue StandardError => e
      $logger.error 'Unable to join MUC. Stacktrace follows:'
      $logger.error e
    end
  end

  #Wir reloaden das Modul
  def reload
    begin
      $logger.info "Starting Jabber reload."
      join_channels #Wir joinen einfach alle Channel erneut. Die Methode handlet das
    rescue StandardError => e
      $logger.error "Reloading failed. Exception thrown:"
      $logger.error e
    end
  end
end

#server starting stuff
db = DbManager.new
#TODO: Wir müssen irgendwie neue Server starten. Vorerst pollen wir die Datenbank
#Ja das ist scheiße unschön.
#TODO: Unschön. Das muss sauberer umgesetzt werden. Alle 60 Sekunden die Datenbank anzufragen ist scheiße
#Es wäre möglich auf nem Redis Channel zu horchen und dann den reload zu triggern. Dafür müsste hier aber noch ein redis listener rein
loop do
  servers = db.loadServers('jabber')
  $logger.debug servers
  servers.each do |server|
    #TODO: Aus irgendeinem Grund sind ein paar Felder leer.
    unless server.nil?
      if servers[server['ID']].nil? #wir starten nur falls da noch kein Objekt von existiert
        begin
          Thread.new do
            jb = JabberBridge.new
            jb.startServer(server['ID'], server['server_url'], server['server_port'],
                           server['user_name'], server['user_password'])
            $logger.info "Server #{server['server_url']} started..."
          end
        rescue StandardError => e
          $logger.error "Server #{server['server_url']} crashed while starting..."
          $logger.error e
        end
      end
    end
  end
  sleep 60
end