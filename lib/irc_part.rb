require "rubygems"
require "IRC"

class IRCBridge
	def self.start(conf)
		@conf = conf
		@bot = IRC.new(conf[:nick], conf[:server], conf[:port], conf[:name])
		IRCEvent.add_callback('endofmotd') { |event| @bot.add_channel(conf[:channel]) }
		IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
		@bot.connect
	end
	def self.handleMessage(message)
		if /#{@conf[:nick]}: (.*)/.match(message.message)
			cmd = /\ (.*)/.match(message.message)[1]
			command(message.from, cmd)
		else
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
