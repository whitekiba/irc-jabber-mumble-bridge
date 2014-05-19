require "rubygems"
require "mumble-ruby"
require 'cgi'
require "sanitize"

class MumbleBridge
	def self.start(conf, bridge)
		if conf[:enabled] == false
			exit
		end
		@my_name = :mumble
		@conf = conf
		@bridge = bridge
		@channel_id = 0
		@mumble = Mumble::Client.new(conf[:server]) do |config|
			config.username = conf[:username]
		end
		@mumble.on_text_message do |msg|
			handleMessage(msg)
		end
		@mumble.on_user_state do |msg|
			handleUserChange(msg)
		end
		bridge.subscribe(@my_name)
		bridge.addPrefix(@my_name, "M")
		Thread.new do
			loop do
				sleep 0.1
				if msg_in = bridge.getNextMessage(@my_name)
					@mumble.text_channel(conf[:channel], CGI.escapeHTML(msg_in))
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
			if @mumble.users[msg.actor].respond_to? :name
				username = @mumble.users[msg.actor].name
				@bridge.broadcast(@my_name, "[#{username}]: #{Sanitize.clean(CGI.unescapeHTML(msg.to_hash()["message"]))}")
				$logger.info msg.to_hash()["message"]
			end
		end
	end
	def self.handleUserChange(msg)
		if @mumble.users[msg.actor].respond_to? :name
			username = @mumble.users[msg.actor].name
			if username == @conf[:username] #if the event is triggered by bridge
				@channel_id = msg.channel_id
			else
				if @mumble.channels[msg.channel_id].name == @conf[:channel]
					@bridge.broadcast(@my_name, " #{username} hat den Channel betreten.")
				else
					if @mumble.users[msg.actor].channel_id == @channel_id
						@bridge.broadcast(@my_name, " #{username} hat den Channel verlassen.")
					end
				end
			end
		end
	end
end
