require 'mysql2'

class ConfigManager
  def initialize
    @db = Mysql2::Client.new(:host => "127.0.0.1", :username => "root")
    @db.select_db('bridge')
  end
  def loadService(service)

  end
  def addServiceToUser(user_id, service, ident_value, server = nil)
    @db.query("")
  end
  #erzeugt einen neuen Datensatz für den User
  #generiert außerdem auch ein secret für die Datenbank
  def addUser(username)
    secret = (0...32).map { (65 + rand(26)).chr }.join
    while !checkSecret(secret) do
      secret = (0...32).map { (65 + rand(26)).chr }.join
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
db_test.addUser('whitekiba')