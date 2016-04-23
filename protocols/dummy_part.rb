require 'rubygems'
require 'redis'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/dummy.log')

class DummyBridge < ModuleBase
  def gen_messages
    @my_name = :dummy
    loop do
      sleep 1
      self.publish(@my_name, 'test')
      $logger.info 'Message gesendet!'
    end
    $logger.info 'Dummy... Dead!'
  end
end

dummy = DummyBridge.new
dummy.gen_messages