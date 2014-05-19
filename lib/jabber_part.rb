require "rubygems"
require "jabbot"

class JabberBridge
	def self.start(conf, bridge)
		if conf[:enabled] == false
			exit
		end
		@my_name = :jabber
		@conf = conf
		@bridge = bridge
		config = Jabbot::Config.new(
			:login => conf[:id],
			:password => conf[:pw],
			:nick => conf[:name],
			:server => conf[:conference_room].split('@')[1],
			:channel => conf[:conference_room].split('@')[0],
			:channel_password => conf[:channel_password],
			:resource => conf[:resource]
		)
		@bot = Jabbot::Bot.new(config)
		msg_handler = Jabbot::Handler.new do |msg, params|
			handleMessage(msg)
		end
		join_handler = Jabbot::Handler.new do |msg, params|
			handleJoin(msg)
		end
		leave_handler = Jabbot::Handler.new do |msg, params|
			handleLeave(msg)
		end
		@bot.handlers[:message] << msg_handler
		@bot.handlers[:join] << join_handler
		@bot.handlers[:leave] << leave_handler
		bridge.subscribe(@my_name)
		bridge.addPrefix(@my_name, "J")
		Thread.new do
			loop do
				sleep 0.1
				if msg_in = bridge.getNextMessage(@my_name)
					@bot.send_message msg_in
				end
			end
		end
		@bot.connect
	end
	def self.handleMessage(message)
		nick = message.user.split("@").first
		if /#{@conf[:nick]}, (.*)/.match(message.text)
			$logger.info "Hier fehlt der Code fuer Kommandos in Jabber!"
		else
			@bridge.broadcast(@my_name, "[#{nick}]: #{message.text}")
			$logger.info message.text
		end
	end
	def self.handleJoin(message)
		@bridge.broadcast(@my_name, " #{message.user} betrat den Chat.")
	end
	def self.handleLeave(message)
		@bridge.broadcast(@my_name, " #{message.user} hat den Chat verlassen.")
	end
end
