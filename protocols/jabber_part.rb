require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc/helper/simplemucclient'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require_relative '../lib/exception_helper'

$logger = Logger.new(File.dirname(__FILE__) + '/jabber.log')
$logger.level = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:loglevel]

class JabberBridge < ModuleBase
  def startServer(id, address, port, username, password)
    @my_name = 'jabber'
    @my_short = 'J'
    @my_id = id
    $logger.info 'New Jabber Server started.'
    $logger.debug "My credentials are: Username: #{username} and Password: #{password}"

    @muc = Hash.new
    @eh = ExceptionHelper.new

    if $config[:dev]
      Jabber::debug = true
    end

    loadSettings

    begin
      @jid = Jabber::JID.new(username)
      @bot = Jabber::Client.new(@jid)
      @bot.connect
      $logger.info 'Connected to server.'
      sleep 2 #ich glaub es ist besser wenn wir hier warten

      @bot.auth(password)
      $logger.info "Authenticated!"

      #channel joinen
      sleep 2
      join_channels
      $logger.info "Channels joined!"
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
            @eh.reset_counter
          rescue StandardError => e
            $logger.error 'Unable to send message. Stacktrace follows:'
            @eh.new_exception(e)
            $logger.error e
          end
        end
      end
    end

    #helper initialisieren
    @eh.poll_for_limit

    loop do
      sleep 60
    end
  end

  def handleMessage(nick, channel, message)
    $logger.debug 'handleMessage called.'
    $logger.debug message
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, message: message, user_id: @@channels[channel])
  end
  def handleJoin(nick)
    $logger.debug 'handleJoin called.'
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, user_id: @@channels[channel], message_type: 'join')
  end
  def handleLeave(nick)
    $logger.debug 'handleLeave called.'
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, user_id: @@channels[channel], message_type: 'part')
  end

  def join_channels
    #wir schreiben unsere Channel in den @muc hash.
    $logger.debug @channels_invert
    @channels_invert.each_value do |channel|
      join_channel(channel)
    end
  end

  def join_channel(channel)
    puts "Test!"
    begin
      if @muc[channel].nil?
        $logger.info "Joining MUC #{channel}"
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
      @eh.new_exception(e)
      $logger.error e
    end
  end

  #Wir reloaden das Modul
  def reload
    begin
      $logger.info "Starting Jabber reload."
      join_channels #Wir joinen einfach alle Channel erneut. Die Methode handlet das
      @blacklist.reload
    rescue StandardError => e
      $logger.error "Reloading failed. Exception thrown:"
      @eh.new_exception(e)
      $logger.error e
    end
  end
end

#server starting stuff
db = DbManager.new
$servers = Hash.new

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
      if $servers[server['ID']].nil? #wir starten nur falls da noch kein Objekt von existiert
        begin
          Thread.new do
            $logger.info "Trying to start thread"
            $servers[server['ID']] = JabberBridge.new
            $servers[server['ID']].startServer(server['ID'], server['server_url'], server['server_port'],
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