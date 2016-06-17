# encoding: utf-8
require 'rubygems'
require 'mumble-ruby'
require 'cgi'
require 'sanitize'
require_relative "../lib/db_manager"
require_relative "../lib/module_base"

$logger = Logger.new(File.dirname(__FILE__) + '/mumble.log')

class MumbleBridge < ModuleBase
  def startServer(serverID, server_url, server_port, server_username)
    @my_name = "mumble"
    @my_short = "M"

    @channels = @db.loadChannels(serverID)
    @channels_invert = @channels.invert

    @mumble = Mumble::Client.new(server_url, server_port) do |config|
      config.username = server_username
    end
    @mumble.on_text_message do |msg|
      handleMessage(msg)
    end
    @mumble.on_user_state do |msg|
      handleUserChange(msg)
    end
    @mumble.on_user_remove do |msg|
      handleUserRemove(msg)
    end
    subscribe(@my_name)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        unless msg_in.nil?
          begin
          @mumble.text_channel(@channels_invert[msg_in["user_id"]], CGI.escapeHTML(msg_in["message"]))
          rescue Exception => e
            $logger.info 'Failed to send Message'
            $logger.info e
          end
        end
      end
    end
    @mumble.connect
    sleep 4 #wir muessen warten weil er den channel sonnst nicht joint
    begin
      @mumble.join_channel(conf[:channel])
    rescue Exception => e
      $logger.info 'Failed to join channel'
      $logger.info e
    end
  end
  def handleMessage(msg)
    $logger.info 'handleMessage wurde aufgerufen.'
    $logger.debug msg.to_hash()
    if /#{@conf[:username]} (.*)/.match(msg.message)
      $logger.info 'Hier fehlt der Kommandocode fuer Mumble'
    else
      if @mumble.users[msg.actor].respond_to? :name
        username = @mumble.users[msg.actor].name
        self.publish(source_network_type: @my_short, source_network: @my_name,
                     nick: username, message: Sanitize.clean(CGI.unescapeHTML(msg.to_hash()['message'])), user_id: @channels[message.channel])
        $logger.info msg.to_hash()['message']
      end
    end
  end
  def handleUserChange(msg)
    $logger.info 'handleUserChange wurde aufgerufen.'
    $logger.debug msg.to_hash()
    if @mumble.users[msg.session].respond_to? :name
      username = @mumble.users[msg.session].name
      $logger.debug "handleUserChange wurde ausgelöst von #{username}"
      if username == @conf[:username] #if the event is triggered by bridge
        @channel_id = msg.channel_id
      else
        if @mumble.channels[msg.channel_id].respond_to? :name
          if @mumble.channels[msg.channel_id].name == @conf[:channel]
            self.publish(source_network_type: @my_short, source_network: @my_name,
                         nick: username, user_id: @channels[channel], message_type: "join")
          else
            if @mumble.users[msg.session].channel_id == @channel_id
              self.publish(source_network_type: @my_short, source_network: @my_name,
                           nick: username, user_id: @channels[channel], message_type: "join")
            end
          end
        end
      end
    else
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: msg.name, user_id: @channels[channel], message_type: "join")
    end
  end
  def handleUserRemove(msg)
    $logger.info 'handleUserRemove wurde aufgerufen.'
    $logger.debug msg.to_hash()
    if @mumble.users[msg.session].respond_to? :name
      username = @mumble.users[msg.session].name
      $logger.info 'Username wurde gefunden'
      self.publish(source_network_type: @my_short, source_network: @my_name,
                   nick: username, user_id: @channels[channel], message_type: "part")
    end
  end
end

#server starting stuff
#wir müssen für jeden Server eine eigene Instanz der MumbleBridge erzeugen
db = DbManager.new
servers = db.loadServers("mumble")
$logger.debug servers
servers.each do |server|
  #ich habe keine ahnung wieso da felder nil sind
  unless server.nil?
    Thread.new do
      begin
        mumble = MumbleBridge.new
        mumble.startServer(server["ID"], server["server_url"], server["server_port"], server["user_name"])
      rescue StandardError => e
        $logger.debug "Mumble crashed. Stacktrace follows."
        $logger.debug e
      end
    end
  end
end

loop do
  sleep 0.1
end