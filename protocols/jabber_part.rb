require 'rubygems'
require 'jabbot'
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
    @channels = @db.loadChannels(id)
    @channels_invert = @channels.invert

    config = Jabbot::Config.new(
      :login => username,
      :password => password,
      :server => address,
      :channel => "test@conference.rout0r.org"
    )
    @bot = Jabbot::Bot.new(config)
    @channels_invert.each do |channel|
      @bot.muc.join("#{channel}@#{address}")
    end
    msg_handler = Jabbot::Handler.new do |msg, params|
      handleMessage(msg)
    end
    join_handler = Jabbot::Handler.new do |msg, params|
      handleJoin(msg)
    end
    leave_handler = Jabbot::Handler.new do |msg, params|
      handleLeave(msg)
    end
    @bot.handlers[:message] << msg_handler
    @bot.handlers[:join] << join_handler
    @bot.handlers[:leave] << leave_handler
    Thread.new do
      loop do
        sleep 0.1
        if msg_in = bridge.getNextMessage(@my_name)
          @bot.send_message(msg_in, @channels_invert[msg_in["user_id"]])
        end
      end
    end
    @bot.connect
  end
  def handleMessage(message)
    $logger.info message
    nick = message.user.split('@').first
    self.publish(source_network_type: @my_short, source_network: @my_name,
                 nick: nick, message: message.text, user_id: @channels[message.channel])
  end
  def handleJoin(message)
    #@bridge.broadcast(@my_name, " #{message.user} betrat den Chat.")
  end
  def handleLeave(message)
    #@bridge.broadcast(@my_name, " #{message.user} hat den Chat verlassen.")
  end
end

jb = JabberBridge.new
jb.startServers