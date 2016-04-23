#!/usr/bin/env ruby
Dir.chdir $pwd unless $pwd.nil?

$:.unshift('protocols/')

require 'rubygems'
require 'yaml'
require 'logger'
require 'redis'
require 'childprocess'

#$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

processes = Hash.new

protocols = ['dummy', 'irc', 'telegram']

protocols.each { |proto|
  processes[proto] = ChildProcess.build('ruby', "protocols/#{proto}_part.rb")
  processes[proto].start
}

loop do
  begin
    processes.each_key { |proc|
      if processes[proc].exited?
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


# vim: tabstop=3
