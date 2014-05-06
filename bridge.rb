#!/usr/bin/env ruby
$:.unshift("lib/")

require "irc_part"
require "jabber_part"

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

Thread.new do
	begin
		IRCBridge.start($config[:irc])
	rescue Exception => e
		$logger.error e
		$logger.error e.backtrace.join("\n")
	end
end

Thread.new do
	begin
		JabberBridge.start($config[:jabber])
	rescue Exception => e
		$logger.error e
		$logger.error e.backtrace.join("\n")
	end
end

loop do
	sleep 0.5
end
