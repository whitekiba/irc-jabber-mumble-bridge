#!/usr/bin/env ruby
Dir.chdir $pwd unless $pwd.nil?

$:.unshift('protocols/')

require 'rubygems'
require 'yaml'
require 'logger'
require 'redis'
require 'childprocess'
require 'tempfile'

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

processes = Hash.new
protocols = $config[:enabled_services]
ChildProcess.build('ruby', 'assistant/assistant_manager.rb').start

puts 'bridge-v2 starting up... (INTEGRATE ALL TEH THINGS!)'

puts 'Starting Mainloop and services.'
loop do
  begin
    protocols.each { |proc|
      #wir haben die if getrennt weil wir sonnst ständig neue prozesse starten
      #wir checken erst ob der auf die methode reagiert
      # falls ja checken wir obs true ist. Falls nicht tun wir nix
      if processes[proc].respond_to?(:exited?)
        if processes[proc].exited?
          puts "#{proc} crashed!"
          processes[proc] = nil #nil setzen damit die gb das ding entfernt
        end
      else
        #starten
        processes[proc] = ChildProcess.build('ruby', "protocols/#{proc}_part.rb")
        puts "#{proc} started."
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
