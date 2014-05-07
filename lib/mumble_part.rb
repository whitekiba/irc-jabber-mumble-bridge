require "rubygems"
require "mumble-ruby"

class MumbleBridge
	def self.start(conf, bridge)
		@my_name = :mumble
		@conf = conf
		@bridge = bridge
		@mumble = Mumble::Client.new(conf[:server]) do |config|
			config.username = conf[:username]
		end
		@mumble.on_text_message do |msg|
			puts msg
			handleMessage(msg)
		end
		bridge.subscribe(@my_name)
		Thread.new do
			loop do
				sleep 0.1
				if msg_in = bridge.getNextMessage(@my_name)
					@mumble.text_channel(conf[:channel], msg_in)
				end
			end
		end
		@mumble.connect
		sleep 2 #wir muessen warten weil er den channel sonnst nicht joint
		@mumble.join_channel(conf[:channel])
	end
	def self.handleMessage(msg)
		if /#{@conf[:username]} (.*)/.match(msg.message)
			$logger.info "Hier fehlt der Kommandocode fuer Mumble"
		else
			username = @mumble.users[msg.actor].name
			@bridge.broadcast(@my_name, "[#{username}]: #{msg.to_hash()["message"]}")
			$logger.info msg.to_hash()["message"]
		end
	end
end
