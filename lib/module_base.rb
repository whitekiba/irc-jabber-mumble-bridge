require 'redis'

class ModuleBase
  def initialize
    @single_con_networks = %w(I T)
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    Thread.new do
      sleep 0.1
      $logger.info('Thread gestartet!')
      @redis_sub.psubscribe('msg.*') do |on|
        on.psubscribe do |channel, subscriptions|
          puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
          $logger.info ('subscribed!')
        end
        on.pmessage do |pattern, channel, message|
          puts "Got message: #{channel}: #{message}"
          $logger.info ('Got message!')
        end
      end

    end
  end
  def publish(api_ver: '1', source_network_type: nil, source_network: nil, source_user:,
              message:, nick:, user_id: nil, network_id: nil , timestamp: nil,
              message_type: 'msg', attachment: nil)
    source_network_type = @my_name_short if source_network_type.nil?
    $logger.info ('publish wurde aufgerufen')
    @redis_pub.publish("msg.#{source_network}", message)
    puts message
  end
end