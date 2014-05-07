require "rubygems"
require "IRC"

class IRCBridge
	def self.start(conf, bridge)
		@my_name = :irc
		@conf = conf
		@bridge = bridge
		@bot = IRC.new(conf[:nick], conf[:server], conf[:port], conf[:name])
		IRCEvent.add_callback('endofmotd') { |event| @bot.add_channel(conf[:channel]) }
		IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
		bridge.subscribe(@my_name)
		Thread.new do
			loop do
				sleep 0.1
				if msg_in = bridge.getNextMessage(@my_name)
					@bot.send_message(conf[:channel], msg_in)
				end
			end
		end
		@bot.connect
	end
	def self.handleMessage(message)
		if /#{@conf[:nick]}: (.*)/.match(message.message)
			cmd = /\ (.*)/.match(message.message)[1]
			command(message.from, cmd)
		else
			@bridge.broadcast(@my_name, "[#{message.from}]: #{message.message}")
			$logger.info message.message
		end
	end
	def self.command(user, command)
		if command == "version"
			ver = `uname -a`
			@bot.send_message(@conf[:channel], "Version? Oh... ich hab sowas nicht nicht :'(")
			@bot.send_message(@conf[:channel], "Aber hey ich hab das hier! Mein OS: #{ver}")
		end
		if @conf[:master] == user
			if command == "ge wek"
				abort
			end
		end
	end
end
