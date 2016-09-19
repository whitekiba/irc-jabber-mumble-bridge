require 'rubygems'
require 'redis'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/dummy.log')

class DummyBridge < ModuleBase
  @die = 60
  @my_short_name = 'D'
  @my_short = 'dummy'
  @my_network_id = 1
  @my_user_id = 1
  def gen_messages
    puts "Dummy starting... Generating test messages (and crashing after #{@die} seconds)"
    @my_name = :dummy
    Thread.new do
      loop do
        sleep 10
        begin
          self.publish(source_user: @my_user_id, source_network: @my_name, message: 'MSG: test', nick: 'dummy', user_id: 1)
          $logger.info 'Message gesendet!'
        rescue StandardError => e
          $logger.debug 'Failed to send message. Stacktrace:'
          $logger.debug e
        end
      end
    end
    Thread.new do
      loop do
        sleep 11
        begin
          self.publish(source_network_type: @my_short, source_network: @my_name,
                       nick: 'dummy', message_type: 'join', user_id: 1)
          $logger.info 'Message gesendet!'
        rescue StandardError => e
          $logger.debug 'Failed to send message. Stacktrace:'
          $logger.debug e
        end
      end
    end
    Thread.new do
      loop do
        sleep 59
        begin
          self.publish(source_network_type: @my_short, source_network: @my_name,
                       nick: 'dummy', message_type: 'broadcast', message: 'Ich bin ein Broadcast')
          $logger.info 'Message gesendet!'
        rescue StandardError => e
          $logger.debug 'Failed to send message. Stacktrace:'
          $logger.debug e
        end
      end
    end
    loop do
      sleep 5
    end
    $logger.info 'Dummy... Dead!'
  end
  def receive_messages
    Thread.new do
      self.receive
    end
  end
end

dummy = DummyBridge.new
dummy.gen_messages