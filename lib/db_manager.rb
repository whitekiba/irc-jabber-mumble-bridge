require 'mysql2'
require 'yaml'

class DbManager
  def initialize
    @config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:database]
    @db = Mysql2::Client.new(:host => @config[:host], :username => @config[:user], :password => @config[:password])
    @db.select_db(@config[:database])
  end

  def loadChannels(server_ID)
    channels = Hash.new
    res = @db.query("SELECT channel_name, user_ID FROM channels WHERE server_ID = #{server_ID}");
    res.each do |entry|
      channels[entry["channel_name"]] = entry["user_ID"]
    end
    channels
  end

  def loadServers(server_ID)
    servers = Array.new
    query = "SELECT * FROM servers WHERE server_type LIKE '#{server_ID}'"
    res = @db.query(query);
    res.each do |entry|
      servers[entry["ID"]] = entry
    end
    servers
  end
  def addServiceToUser(user_id, service, ident_value, server = nil, server_username = nil)
    @db.query("INSERT INTO `services` (`ID`, `user_ID`, `ident_value`, `channel`) VALUES (NULL, '#{user_id}', '#{ident_value}', "")")
  end

  def addServer(server_url, server_port, server_type)
    @db.query("")
  end

  #erzeugt einen neuen Datensatz für den User
  #generiert außerdem auch ein secret für die Datenbank
  def addUser(username)
    secret = (0..32).map { (65 + rand(26)).chr }.join
    while !checkSecret(secret) do
      secret = (0..32).map { (65 + rand(26)).chr }.join
    end
    @db.query("INSERT INTO `users` (`ID`, `username`, `secret`) VALUES (NULL, '#{username}', '#{secret}');")
    secret #return the secret
  end

  def checkSecret(secret)
    res = @db.query("SELECT * FROM `users` WHERE `secret` LIKE '#{secret}'")
    if res.count > 0
      return false
    end
    true
  end
end

#db_test = DbManager.new
#db_test.addUser('leopold')