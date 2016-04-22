require "rubygems"
require "IRC"

class IRCBridge
  def self.start(conf, bridge)
    if conf[:enabled] == false
      exit
    end
    @my_name = :irc
    @conf = conf
    @bridge = bridge
    @bot = IRC.new(conf[:nick], conf[:server], conf[:port], conf[:name])
    IRCEvent.add_callback('endofmotd') { |event| @bot.add_channel(conf[:channel]) }
    IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
    IRCEvent.add_callback('join') { |event| joinMessage event }
    IRCEvent.add_callback('part') { |event| partMessage event }
    IRCEvent.add_callback('quit') { |event| quitMessage event }
    bridge.subscribe(@my_name)
    bridge.addPrefix(@my_name, "I")
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
      unless @conf[:ignore].include?(message.from)
        if /^\x01ACTION (.)+\x01$/.match(message.message)
          @bridge.broadcast(@my_name, " * [#{message.from}] #{message.message.gsub(/^\x01ACTION |\x01$/, "")}")
        else
          @bridge.broadcast(@my_name, "[#{message.from}]: #{message.message}")
        end
        $logger.info message.message
      end
    end
  end

  def self.joinMessage(event)
    if event.from != @conf[:nick]
      @bridge.broadcast(@my_name, "#{event.from} kam in den Channel.")
    end
  end

  def self.partMessage(event)
    if event.from != @conf[:nick]
      @bridge.broadcast(@my_name, "#{event.from} hat den Channel verlassen")
    end
  end

  def self.quitMessage(event)
    if event.from != @conf[:nick]
      @bridge.broadcast(@my_name, "#{event.from} hat den Server verlassen")
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
