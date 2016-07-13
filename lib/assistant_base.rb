require 'redis'
require 'json'
require_relative 'language'

class AssistantBase
  def initialize
    @userid = ARGV[0]
    @lang = Language.new
    @timeout = 1 #das ist der timeout

    @last_command = Time.now
    @next_step = Array.new
    @assistant_message = Array.new
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    @valid_servers = {"telegram" => "Telegram",
                      "irc" => "IRC",
                      "mumble" => "Mumble",
                      "jabber" => "Jabber"}
  end

  def subscribe(name)
    Thread.new do
      sleep 0.1
      @redis_sub.psubscribe("assistant.#{@userid}") do |on|
        on.pmessage do |pattern, channel, message|
          data = JSON.parse(message)
          resetTimeout
          #start(data) if data['source_network_type'].eql?(name) & data['message'].eql?('/start')
          @assistant_message.unshift(data)
        end
      end
    end
  end
  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    json = JSON.generate ({
        'message' => message,
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    @redis_pub.publish("assistant.#{@userid}", json)
    puts json
  end
  def waitForTimeout
    loop do
      sleep 1
      break if @last_command < (Time.now - (@timeout*60)) #5 ist der timeout
    end
  end
  def resetTimeout
    $logger.debug "resetTimeout triggered. New time!"
    @last_command = Time.now
  end
  def valid_step?(step)
    unless @next_step.index(step).nil?
      true
    end
    false
  end
  def next_steps(*args)
    @next_step.clear
    args.each do |arg|
      @next_step << arg
    end
  end
  def validate_parameters(*args)

  end
  def is_valid_server?(server)
    if @valid_servers.key?(server)
      true
    end
  end
  def get_valid_servers
    valid_server_text = @lang.get("valid_server_intro")
    @valid_servers.each_value do |server|
      valid_server_text << "- #{server}\n"
    end
    valid_server_text
  end
end


