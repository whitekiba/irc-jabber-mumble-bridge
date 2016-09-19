require 'rubygems'
require 'telegram/bot'
require 'cgi'
require 'sanitize'
require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require 'logger'

$logger = Logger.new(File.dirname(__FILE__) + '/telegram.log')

class TelegramBridge < ModuleBase
  def receive
    @my_name = 'telegram'
    @my_short = 'T'
    @my_id = 3
    $logger.info 'Telegram process starting...'
    @telegram = Telegram::Bot::Client.new($config[:telegram][:token], logger: $logger)
    @db = DbManager.new

    #Channel laden
    loadChannels

    subscribe(@my_name)
    subscribe_cmd(@my_name)
    subscribeAssistant(@my_name)
    Thread.new do
      loop do
        msg_in = @messages.pop
        #$logger.debug("Length of @message seen by #{@my_name}: #{@messages.length}")
        unless msg_in.nil?
          $logger.info msg_in
          begin
            if msg_in["message_type"] == 'msg'
              @telegram.api.send_message(chat_id: @chat_ids_invert[msg_in['user_id']],
                                         text: "[#{msg_in['source_network_type']}][#{msg_in['nick']}] #{msg_in['message']}")
            else
              case msg_in["message_type"]
                when 'join'
                  @telegram.api.send_message(chat_id: @chat_ids_invert[msg_in['user_id']],
                                             text: "#{msg_in["nick"]} kam in den Channel")
                when 'part'
                  @telegram.api.send_message(chat_id: @chat_ids_invert[msg_in['user_id']],
                                             text: "#{msg_in["nick"]} hat den Channel verlassen")
                when 'quit'
                  @telegram.api.send_message(chat_id: @chat_ids_invert[msg_in['user_id']],
                                             text: "#{msg_in["nick"]} hat den Server verlassen")
              end
            end
          rescue StandardError => e
            $logger.error e
          end
        end
      end
    end
    Thread.new do
      loop do
        msg_in = @assistantMessages.pop
        unless msg_in.nil?
          $logger.info 'Got Assistant message'
          begin
            $logger.info msg_in
            $logger.info msg_in['reply_markup'].class
            @telegram.api.send_message(chat_id: msg_in['chat_id'], text: msg_in['message'], reply_markup: msg_in['reply_markup'])
          rescue StandardError => e
            $logger.error 'Got Exception!'
            $logger.error e
          end
        end
      end
    end
    #TODO: Weiterer Thread um Nachrichten direkt an User zu senden.
    # Das ganze kriegt einen eigenen Channel
    # In der eingehenden Nachricht wird es keine chat_id geben. Stattdessen wird die Userid aus der Datenbank gesendet.
    # Der Thread macht dann einen Lookup der Userid und sucht sich das für sein Protokoll passende Merkmal raus
    # Auf Basis dieser ID wird die Nachricht dass als Privatnachricht gesendet. 
    @telegram.listen do |msg|
      handleMessage(msg)
    end
  end
  #Wir reloaden das Modul
  def reload
    begin
      $logger.info "Starting Telegram reload."
      loadChannels
    rescue StandardError => e
      $logger.error "Reloading failed. Exception thrown:"
      $logger.error e
    end
  end
  def loadChannels
    @chat_ids = nil unless @chat_ids.nil? #löschen wir den Kram mal
    @chat_ids_invert = nil unless @chat_ids_invert.nil?
    @chat_ids = @db.loadChannels(@my_id)
    @chat_ids_invert = @chat_ids.invert
  end
  def handleMessage(msg)
    #$logger.info 'handleMessage wurde aufgerufen!'
    $logger.info msg
    if @chat_ids[msg.chat.id.to_s].nil?
      unless msg.new_chat_member.nil?
        if msg.from.first_name == 'bridge'
          @telegram.api.send_message(chat_id: msg.chat.id, text: "Ohai. I am new. This chat has ID: #{msg.chat.id}")
        end
      end
    end

    unless msg.text.nil?
      begin
        is_assistant = false
        is_assistant = true if msg.chat.type.eql?('private')
        publish(source_network_type: @my_short,
                user_id: @chat_ids[msg.chat.id.to_s],
                source_network: @my_name, source_user: 'empty',
                nick: msg.from.first_name, message: msg.text,
                is_assistant: is_assistant, chat_id: msg.chat.id)
      rescue StandardError => e
        $logger.error "publish hat eine Exception geworfen."
        $logger.error e
      end
    end
  end
end

tg = TelegramBridge.new
tg.receive