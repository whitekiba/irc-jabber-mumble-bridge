require 'redis'

class ModuleBase
  def initialize
    @redis = Redis.new(:host => 'localhost', :port => 7777)
  end
  def publish(source, message)
    $logger.info ('publish wurde aufgerufen')
    @redis.publish(source, message)
    puts message
  end
end