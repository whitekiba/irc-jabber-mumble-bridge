require 'rubygems'
require 'IRC'
require_relative '../lib/module_base'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/irc.log')

class IRCBridge < ModuleBase
  def receive
    @my_name = 'irc'

    @bot = IRC.new($config[:irc][:nick], $config[:irc][:server], $config[:irc][:port], $config[:irc][:name])
    IRCEvent.add_callback('endofmotd') { |event| @bot.add_channel("#bridge-test") }
    IRCEvent.add_callback('privmsg') { |event| handleMessage(event) }
    IRCEvent.add_callback('join') { |event| joinMessage event }
    IRCEvent.add_callback('part') { |event| partMessage event }
    IRCEvent.add_callback('quit') { |event| quitMessage event }

    subscribe(@my_name)
    Thread.new do
      loop do
        sleep 0.1
        msg_in = @messages.pop
        #$logger.info "State of message array: #{msg_in.nil?}"
        if !msg_in.nil?
          $logger.info msg_in
          @bot.send_message("#bridge-test", msg_in["message"])
        end
      end
    end

    @bot.connect
  end

  def handleMessage(message)
    $logger.info "handleMessage wurde aufgerufen"
    if /^\x01ACTION (.)+\x01$/.match(message.message)
      self.publish(source_network_type: @my_name, message: " * [#{message.from}] #{message.message.gsub(/^\x01ACTION |\x01$/, '')}", chat_id: '-145447289')
    else
      self.publish(source_network_type: @my_name, source_user: 'empty', nick: message.from, message: message.message, chat_id: '-145447289')
    end
    $logger.info message.message
  end

  def joinMessage(event)
    if event.from != @conf[:nick]
      self.publish(source_network_type: @my_name, message: "#{event.from} kam in den Channel.")
    end
  end

  def partMessage(event)
    if event.from != @conf[:nick]
      self.publish(source_network_type: @my_name, message: "#{event.from} hat den Channel verlassen")
    end
  end

  def quitMessage(event)
    if event.from != @conf[:nick]
      self.publish(source_network_type: @my_name, message: "#{event.from} hat den Server verlassen")
    end
  end

  def command(user, command)
    if command == 'version'
      ver = `uname -a`
      @bot.send_message(@conf[:channel], "Version? Oh... ich hab sowas nicht nicht :'(")
      @bot.send_message(@conf[:channel], "Aber hey ich hab das hier! Mein OS: #{ver}")
    end
    if @conf[:master] == user
      if command == 'ge wek'
        abort
      end
    end
  end
end

irc = IRCBridge.new
irc.receive