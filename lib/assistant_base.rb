require 'redis'
require 'json'
class AssistantBase
  def initialize
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
  end

  def subscribe(name)
    Thread.new do
      sleep 0.1
      @redis_sub.psubscribe('assistant.*') do |on|
        on.pmessage do |pattern, channel, message|
          data = JSON.parse(message)
          start(data) if data['source_network_type'].eql?(name) & data['message'].eql?('/start')
        end
      end
    end
  end
  def publish(api_ver: '1', message: nil, chat_id: nil, buttons: nil)
    json = JSON.generate ({
        'message' => message,
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'buttons' => buttons
    })
    @redis_pub.publish("assistant.", json)
    puts json
  end
end


