#!/usr/bin/env ruby
Dir.chdir $pwd unless $pwd.nil?

$:.unshift("lib/")

require "irc_part"
require "jabber_part"
require "mumble_part"

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

class Bridge
	def initialize
		@messages = Hash.new #hier werden alle nachrichten reingepumpt
		@subscribers = [] #die liste der endpunkte
		@prefixes = Hash.new #prefixe fuer nachrichten
	end
	def broadcast(from, message)
		$logger.info "Broadcast message called for #{from}"
		if !@prefixes[from].nil?
			message = "[#{@prefixes[from]}]#{message}"
		end
		@subscribers.each { |sub|
			if sub != from
				@messages[sub] << message
			end
		}
	end
	def subscribe(name)
		if @subscribers.index(name).nil?
			@subscribers << name
			@messages[name] = []
		end
	end
	def addPrefix(from, prefix)
		@prefixes[from] = prefix
	end
	def getNextMessage(from)
		@messages[from].shift
	end
end

bridge = Bridge.new

Thread.new do
	begin
		IRCBridge.start($config[:irc], bridge)
	rescue Exception => e
		$logger.error e
		$logger.error e.backtrace.join("\n")
	end
end

Thread.new do
	begin
		JabberBridge.start($config[:jabber], bridge)
	rescue Exception => e
		$logger.error e
		$logger.error e.backtrace.join("\n")
	end
end

Thread.new do
	begin
		MumbleBridge.start($config[:mumble], bridge)
	rescue Exception => e
		$logger.error e
		$logger.error e.backtrace.join("\n")
	end
end

loop do
	sleep 0.5
end
