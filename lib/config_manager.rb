require 'mysql2'
require 'yaml'

class ConfigManager
  def initialize
    @config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:database]
    @db = Mysql2::Client.new(:host => @config[:host], :username => @config[:user], :password => @config[:password])
    @db.select_db(@config[:database])
  end
  def loadService(service)
    services = Array.new
    res = @db.query("SELECT * FROM services WHERE service LIKE '#{service}'");
    res.each do |entry|
      puts entry
      services[entry["user_ID"]] = entry["channel"]
    end
    puts services
  end
  def addServiceToUser(user_id, service, ident_value, server = nil, server_username = nil)
    @db.query("INSERT INTO `services` (`ID`, `user_ID`, `ident_value`, `channel`) VALUES (NULL, '#{user_id}', '#{ident_value}', "")")
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

db_test = ConfigManager.new
db_test.loadService('irc')