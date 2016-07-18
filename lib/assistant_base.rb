require 'redis'
require 'json'
require 'uri'
require_relative 'language'
require_relative '../lib/db_manager'

class AssistantBase
  def initialize
    @userid = ARGV[0]
    @lang = Language.new
    @timeout = 1 #das ist der timeout

    @last_command = Time.now
    @next_step = Array.new
    @assistant_message = Array.new
    @db = DbManager.new
    @redis_pub = Redis.new(:host => 'localhost', :port => 7777)
    @redis_sub = Redis.new(:host => 'localhost', :port => 7777)
    @valid_servers = {'telegram' => 'Telegram',
                      'irc' => 'IRC',
                      'mumble' => 'Mumble',
                      'jabber' => 'Jabber'}
  end

  def subscribe(name)
    Thread.new do
      sleep 0.1
      @redis_sub.psubscribe("assistant.#{@userid}") do |on|
        on.pmessage do |pattern, channel, message|
          data = JSON.parse(message)
          resetTimeout
          #TODO: Code checken. Keine ahnung wofür das mal war
          #start(data) if data['source_network_type'].eql?(name) & data['message'].eql?('/start')
          @assistant_message.unshift(data)
        end
      end
    end
  end
  def publish(api_ver: '1', message: nil, chat_id: nil, reply_markup: nil)
    json = JSON.generate ({
        'message' => message.force_encoding('UTF-8'),
        'source_network_type' => 'assistant',
        'chat_id' => chat_id,
        'reply_markup' => reply_markup
    })
    @redis_pub.publish("assistant.#{@userid}", json)
  end
  def waitForTimeout
    loop do
      sleep 1
      break if @last_command < (Time.now - (@timeout*60)) #5 ist der timeout
    end
  end
  def resetTimeout
    $logger.debug 'resetTimeout triggered. New time!'
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
  def get_available_servers(user_id)
    available_server_text = @lang.get('available_server_intro')
    @db.userServers(user_id).each_value do |av_server|
      available_server_text << "#{av_server['ID']} - #{av_server['server_url']}\n"
    end
    available_server_text
  end
  def get_channels(user_id)
    message = @lang.get('your_channels')
    @db.userChannels(user_ID).each_value do |av_channel|
      message << "#{av_channel['ID']} - #{av_channel['channel_name']}\n"
    end
    message
  end
  def get_valid_servers
    valid_server_text = @lang.get('valid_server_intro')
    @valid_servers.each_value do |server|
      valid_server_text << "- #{server}\n"
    end
    valid_server_text
  end
  def send_command(target, command)
    if @db.valid_server?(target)
      @redis_pub.publish("cmd.#{target}", command)
    end
  end
  def reload(target)
    send_command(target, command)
  end
  def start_new_servers(type)
    #TODO: Da wir die Multiserver funktion noch nicht ganz stabil haben muss das noch geschrieben werden
    #hier sollte ein command kommen welches den core anweist neue Server zu starten
    #parameter sind noch nicht klar, einbindung ist noch nicht klar
  end
end


