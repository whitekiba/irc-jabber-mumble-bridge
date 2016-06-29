#!/usr/bin/env ruby
Dir.chdir $pwd unless $pwd.nil?

$:.unshift('protocols/')

require 'rubygems'
require 'yaml'
require 'logger'
require 'redis'
require 'childprocess'

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

processes = Hash.new

protocols = ['irc', 'telegram', 'jabber']

protocols.each { |proto|
  processes[proto] = ChildProcess.build('ruby', "protocols/#{proto}_part.rb")
  processes[proto].start
}

ChildProcess.build('ruby', "assistant/assistant_manager.rb").start

puts "bridge-v2 starting up... (INTEGRATE ALL TEH THINGS!)"

puts "Starting Mainloop and services."
loop do
  begin
    processes.each_key { |proc|
      if processes[proc].exited?
        puts "#{proc} started or restarted."
        processes[proc].start
      end
    }
    sleep 1
  rescue StandardError => e
    $logger.error e
    $logger.error e.backtrace.join("\n")
    #bridge.broadcast(:core, " Unable to handle exception. Going down!")
    sleep 1
    abort
  end
end
