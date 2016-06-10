require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc/helper/simplemucclient'
require '../lib/module_base'
require '../lib/db_manager'

$logger = Logger.new(File.dirname(__FILE__) + '/jabber.log')

class JabberBridge < ModuleBase
  def startServers
    @my_name = "jabber"
    @my_short = "J"
    @db = DbManager.new
    servers = @db.loadServers(@my_name)
    servers.each do |server|
      puts server
      #TODO: Aus irgendeinem Grund sind ein paar Felder leer.
      unless server.nil?
        begin
          Thread.new do
            startServer(server["ID"], server["server_url"], server["server_port"],
                        server["user_name"], server["server_password"])
            $logger.info "Server #{server["server_url"]} started..."
          end
        rescue StandardError => e
          $logger.info "Server #{server["server_url"]} crashed while starting..."
          $logger.info e
        end
      end
    end
    loop do
      sleep 0.1
    end
  end
  def startServer(id, address, port, username, password)
    @db = DbManager.new
    $logger.info "New Jabber Server started."
    @muc = Hash.new
    @channels = @db.loadChannels(id)
    $logger.info @channels
    #wird genutzt für die channel zu user zuordnung. channel name => user id
    @channels_invert = @channels.invert

    begin
      @jid = Jabber::JID.new(username)
      @bot = Jabber::Client.new(@jid)
      @bot.connect
      $logger.info "Connected to server."
      @bot.auth(password)
    rescue StandardError => e
      $logger.info e
    end
    #wir schreiben unsere Channel in den @muc hash.
    @channels_invert.each do |channel|
      $logger.info "Joining MUC #{channel}"
      begin
        @muc[channel] = Jabber::MUC::SimpleMUCClient.new(@bot)
        @muc[channel].join("#{channel}@#{address}")
        @muc[channel].on_message { |time,nick,text|
          handleMessage(nick, channel, text)
        }
      rescue StandardError => e
        $logger.info "Unable to join MUC. Stacktrace follows:"
        $logger.info e
      end
    end
    Thread.new do
      loop do
        sleep 0.1
        if msg_in = bridge.getNextMessage(@my_name)
          @bot.send_message(msg_in, @channels_invert[msg_in["user_id"]])
        end
      end
    end
  end
  def handleMessage(nick, channel, message)
    $logger.info message
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, message: message.text, user_id: @channels[channel])
  end
  def handleJoin(message)
    #@bridge.broadcast(@my_name, " #{message.user} betrat den Chat.")
  end
  def handleLeave(message)
    #@bridge.broadcast(@my_name, " #{message.user} hat den Chat verlassen.")
  end
end

jb = JabberBridge.new
jb.startServer(1, "rout0r.org", 5222, "bridge@rout0r.org", "Ulavewabe774")