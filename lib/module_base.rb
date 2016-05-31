require 'redis'
require 'json'
require 'yaml'

class ModuleBase
  def initialize
    $config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')
    @single_con_networks = %w(I T)
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_assistant_sub = Redis.new(:host => 'localhost', :port => 7777)
    @messages = Array.new
    @assistantMessages = Array.new
  end
  def subscribe(name)
    Thread.new do
      sleep 0.1
      $logger.info('Thread gestartet!')
      @redis_sub.psubscribe('msg.*') do |on|
        on.psubscribe do |channel, subscriptions|
          puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
          $logger.info ('subscribed!')
        end
        on.pmessage do |pattern, channel, message|
          $logger.info ("Got message! #{message}")
          data = JSON.parse(message)
          if data["source_network_type"] != name
            $logger.info data
            @messages.unshift(data)
            $logger.info("Length of @message #{@messages.length}")
          end
        end
      end
    end
  end
  def subscribeAssistant(name)
    Thread.new do
      sleep 0.1
      $logger.info('Thread gestartet!')
      @redis_assistant_sub.psubscribe('assistant.*') do |on|
        on.psubscribe do |channel, subscriptions|
          puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
          $logger.info ('subscribed to assistant channel!')
        end
        on.pmessage do |pattern, channel, message|
          $logger.info ("Got message! #{message}")
          data = JSON.parse(message)
          if data["source_network_type"] != name
            $logger.info data
            @assistantMessages.unshift(data)
            $logger.info("Length of @message #{@assistantMessages.length}")
          end
        end
      end
    end
  end
  def publish(api_ver: '1', source_network_type: nil, source_network: nil, source_user:,
              message:, nick:, user_id: nil, network_id: nil , timestamp: nil,
              message_type: 'msg', attachment: nil, is_assistant: false, chat_id: nil)
    source_network_type = @my_name_short if source_network_type.nil?
    $logger.info ('publish wurde aufgerufen')
    json = JSON.generate ({
        'message' => message,
        'nick' => nick,
        'source_network_type' => source_network_type,
        'source_network' => source_network,
        'source_user' => source_user,
        'user_id' => user_id,
        'network_id' => network_id,
        'timestamp' => timestamp,
        'message_type' => message_type,
        'attachment' => attachment,
        'chat_id' => chat_id
              })
    @redis_pub.publish("msg.#{source_network}", json) if !is_assistant
    @redis_pub.publish("assistant.#{source_network}", json) if is_assistant
    puts json
  end
end