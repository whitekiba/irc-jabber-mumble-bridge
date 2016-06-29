require 'mysql2'
require 'yaml'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/db_manager.log')

class DbManager
  def initialize
    @config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:database]
    @db = Mysql2::Client.new(:host => @config[:host], :username => @config[:user], :password => @config[:password])
    @db.select_db(@config[:database])
  end

  def loadChannels(server_ID)
    channels = Hash.new
    res = @db.query("SELECT channel_name, user_ID FROM channels WHERE server_ID = #{server_ID}")
    res.each do |entry|
      channels[entry["channel_name"]] = entry["user_ID"]
    end
    channels
  end

  def loadServers(server_type)
    servers = Array.new
    query = "SELECT * FROM servers WHERE server_type LIKE '#{server_type}'"
    res = @db.query(query)
    res.each do |entry|
      servers[entry["ID"]] = entry
    end
    servers
  end

  #server hinzufügen. Im Grunde nur aliase für addServer
  def addJabberServer(server_url, server_port, username, password, user_ID)
    addServer(server_url, server_port, "jabber", username, password, user_ID)
  end
  def addMumbleServer(server_url, server_port, username)
    addServer(server_url, server_port, "mumble", username)
  end
  def addIRCServer(server_url, server_port, username)
    addServer(server_url, server_port, "irc", username)
  end

  def addServer(server_url, server_port, server_type, user_name, user_password = nil, user_ID = nil)
    exit if user_name == ""
    server_port.to_int if server_port.respond_to?(:to_int)
    user_ID = "NULL" if user_ID.nil?
    user_password = "NULL" if user_password.nil?
    sql = "INSERT INTO `servers` (`ID`, `user_ID`, `server_url`, `server_port`, `server_type`, `user_name`, `user_password`)
            VALUES (NULL, #{user_ID}, '#{server_url}', '#{server_port}', '#{server_type}', '#{user_name}', '#{user_password}');"
    @db.query(sql)
  end

  #channel hinzufügen
  #für channel sind user_IDs pflicht. Anders können wir die nicht zuordnen
  def addChannel(user_ID, server_ID, channel, channel_password = nil)
    channel_password = "NULL" if channel_password.nil?
    sql = "INSERT INTO `channels` (`ID`, `user_ID`, `server_ID`, `channel_name`, `channel_password`)
            VALUES (NULL, '#{user_ID}', '#{server_ID}', '#{channel}', #{channel_password})"
    @db.query(sql)
  end

  #erzeugt einen neuen Datensatz für den User
  #generiert außerdem auch ein secret für die Datenbank
  def addUser(username, email = nil)
    email = "NULL" if email.nil?
    secret = (0..32).map { (65 + rand(26)).chr }.join
    while !checkSecret(secret) do
      secret = (0..32).map { (65 + rand(26)).chr }.join
    end
    @db.query("INSERT INTO `users` (`ID`, `username`, `email`, `secret`) VALUES (NULL, '#{username}', '#{email}', '#{secret}');")
    secret #return the secret
  end

  def authUser(username, secret)
    res = @db.query("SELECT ID FROM `users` WHERE `username` LIKE '#{username}' AND `secret` LIKE '#{secret}'")
    $logger.info res
    if res.count > 0
      #TODO: Da müssen wir die ID zurückgeben lassen
      res
    end
    false
  end

  def checkSecret(secret)
    res = @db.query("SELECT * FROM `users` WHERE `secret` LIKE '#{secret}'")
    if res.count > 0
      return false
    end
    true
  end
end