require 'rubygems'
require 'redis'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/dummy.log')

class DummyBridge < ModuleBase
  @my_short_name = 'D'
  @my_network_id = 1
  @my_user_id = 1
  def gen_messages
    puts 'Dummy starting... Generating test messages'
    @my_name = :dummy
    loop do
      sleep 1
      self.publish(source_user: @my_user_id, message: 'test', nick: 'nickname')
      $logger.info 'Message gesendet!'
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