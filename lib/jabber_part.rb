require "rubygems"
require "jabbot"

class JabberBridge
	def self.start(conf)
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
		@bot.connect
	end
end
