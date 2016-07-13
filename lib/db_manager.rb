require 'mysql2'
require 'yaml'
require 'logger'

#$logger = Logger.new(File.dirname(__FILE__) + '/db_manager.log')

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

  def loadServers(server_type = nil, user_id = nil)
    servers = Array.new
    if !server_type.nil?
      query = "SELECT * FROM servers WHERE server_type LIKE '#{server_type}'"
    elsif !user_id.nil?
      query = "SELECT * FROM servers WHERE user_ID = '#{user_id}'"
    else
      query = "SELECT * FROM servers'"
    end

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

  def addServer(server_url, server_port, server_type, user_name = "bridge", user_password = "NULL", user_ID = "NULL")
    server_port.to_int if server_port.respond_to?(:to_int)
    user_ID = "NULL" if user_ID.nil?
    user_password = "NULL" if user_password.nil?
    user_name = "bridgie" if user_name.nil?
    sql = "INSERT INTO `servers` (`ID`, `user_ID`, `server_url`, `server_port`, `server_type`, `user_name`, `user_password`)
            VALUES (NULL, #{user_ID}, '#{server_url}', '#{server_port}', '#{server_type}', '#{user_name}', '#{user_password}');"
    $logger.debug sql
    res = @db.query(sql)
    $logger.debug res
  end

  def getServerCount(user_ID)
    @db.query("SELECT ID FROM servers WHERE user_ID = #{user_ID}").count
  end
  def hasServer?(user_ID, server_type)
    if ['telegram', 'irc'].include? server_type
      true
    else
      res = @db.query("SELECT ID FROM servers WHERE user_ID = #{user_ID} AND server_type LIKE '#{server_type}'")
      if res.count > 0
        true
      else
        false
      end
    end
  end
  def getServers(user_ID)
    return_vars = Hash.new
    res = @db.query("SELECT ID, server_url, server_port, server_type FROM servers WHERE user_ID = #{user_ID}")
    res.each do |entry|
      return_vars[entry["ID"]] = entry
    end
  end
  def getServerID(server_url, server_port)
    @db.query("SELECT ID FROM servers WHERE server_url LIKE '#{server_url}' AND server_port LIKE '#{server_port}'").fetch_hash["ID"]
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
      $logger.debug "Fetched ID: #{res.first["ID"]}"
      res.first["ID"]
    else
      false
    end
  end

  def checkSecret(secret)
    res = @db.query("SELECT * FROM `users` WHERE `secret` LIKE '#{secret}'")
    if res.count > 0
      return false
    end
    true
  end
end