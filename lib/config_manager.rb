require 'mysql2'

class ConfigManager
  def initialize
  end
  def loadService(service)

  end
  def addServiceToUser(user_id, service, ident_value, server = nil)

    end
  end
  #erzeugt einen neuen Datensatz für den User
  #generiert außerdem auch ein secret für die Datenbank
  def addUser(username)
    secret = (0...14).map { (65 + rand(26)).chr }.join
  end
  def
end