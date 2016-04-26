require 'redis'

class ModuleBase
  def initialize
    @vars
    @redis = Redis.new(:host => 'localhost', :port => 7777)
    Thread.new do
      @redis.subscribe('msg.*') do |sub_msg|
        #handle message. eventuell ne extra methode aufrufen
      end
    end
  end
  def publish(source, message)
    $logger.info ('publish wurde aufgerufen')
    @redis.publish(source, message)
    puts message
  end
end