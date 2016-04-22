require "mongo"

class ConfigManager
  def initialize
    @mongodb = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'mydb')
  end
  def loadUser

  end
  def saveUser

  end
end