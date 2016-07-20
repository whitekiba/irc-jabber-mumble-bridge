require 'redis'
require 'json'
require 'yaml'

class ModuleBase
  def initialize
    $config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')
    @single_con_networks = %w(I T)
    @redis_pub = Redis.new(:host => $config[:redis][:host], :port => $config[:redis][:port])
    @redis_sub = Redis.new(:host => $config[:redis][:host], :port => $config[:redis][:port])
    @redis_cmd_sub = Redis.new(:host => $config[:redis][:host], :port => $config[:redis][:port])
    @redis_assistant_sub = Redis.new(:host => $config[:redis][:host], :port => $config[:redis][:port])
    @messages = Array.new
    @messages_cmd = Array.new
    @assistantMessages = Array.new
  end
  def subscribe(name)
    Thread.new do
      sleep 0.1
      $logger.info('Thread gestartet!')
      @redis_sub.psubscribe('msg.*') do |on|
        on.psubscribe do |channel, subscriptions|
          $logger.info "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        on.pmessage do |pattern, channel, message|
          $logger.debug ("Got message! #{message}")
          data = JSON.parse(message)
          if data['source_network'] != name
            $logger.debug data
            @messages.unshift(data)
            $logger.debug("Length of @message #{@messages.length}")
          end
        end
      end
    end
  end
  #Der Commandchannel. Schläft mehr und subscribed
  def subscribe_cmd(id)
    Thread.new do
      sleep 1
      $logger.info('Thread gestartet!')
      @redis_cmd_sub.subscribe("cmd.#{id}") do |on|
        on.subscribe do |channel, subscriptions|
          $logger.info "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        on.message do |channel, message|
          $logger.debug ("Got cmd! Message: #{message} Channel: #{channel}")
          @messages_cmd.unshift(message)
        end
      end
    end
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages_cmd.pop
        #$logger.info "State of cmd array: #{msg_in.nil?}"
        unless msg_in.nil?
          $logger.info "New message in cmd array: #{msg_in}"
          command(msg_in)
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
          $logger.info "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        on.pmessage do |pattern, channel, message|
          $logger.info ("Got message! #{message}")
          $logger.info "Hi my name is #{name}"
          data = JSON.parse(message)
          if data['source_network'] != name
            $logger.debug data
            @assistantMessages.unshift(data)
            $logger.debug("Length of @assistantMessages #{@assistantMessages.length}")
          else
            $logger.debug 'Ignored message because it was mine'
          end
        end
      end
    end
  end
  def publish(api_ver: '1', source_network_type: nil, source_network: nil, source_user: nil,
              message: nil, nick:, user_id:, network_id: nil , timestamp: nil,
              message_type: 'msg', attachment: nil, is_assistant: false, chat_id: nil)
    source_network_type = @my_name_short if source_network_type.nil?
    #TODO: testen ob das wirklich funktioniert
    unless message_type == 'join' || message_type == 'part'
      $logger.error 'Da wurde eine Fehlerhafte Nachricht gesendet.' if message.nil?
    end
    $logger.debug ('publish wurde aufgerufen')
    json = JSON.generate ({
        'message' => message.force_encoding('UTF-8'),
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
    $logger.debug json
    @redis_pub.publish("msg.#{source_network}", json) if !is_assistant
    @redis_pub.publish('assistant_all', json) if is_assistant #wir publishen nicht auf assistant.*
  end
  #TODO: Hier könnte man das interne befehlssystem reinhängen
  def command(command, args = nil)
    begin
      $logger.info 'Received command from Redis. running methods'
      if command == 'reload'
        #if self.respond_to? reload
          reload
        #end
      end
    rescue StandardError => e
      $logger.error "Command triggered exception:"
      $logger.error e
    end
  end
end