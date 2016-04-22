require "rubygems"
require 'redis'
require_relative "./module_base"
require "logger"

$logger = Logger.new(File.dirname(__FILE__) + '/dummy.log')

class DummyBridge < ModuleBase
  def gen_messages
    @my_name = :dummy
    Thread.new do
      loop do
        sleep 1
        self.publish(@my_name, "test")
        $logger.info "Message gesendet!"
      end
    end
    sleep 60
  end
end

dummy = DummyBridge.new
dummy.gen_messages