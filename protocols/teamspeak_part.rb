require_relative '../lib/module_base'
require_relative '../lib/db_manager'
require 'teamspeak-ruby'

$logger = Logger.new(File.dirname(__FILE__) + '/teamspeak.log')
$logger.level = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:loglevel]

class TeamspeakBridge < ModuleBase
  SPECIAL_CHARS = [
      ['\\\\', '\\'],
      ['\\/', '/'],
      ['\\s', ' '],
      ['\\p', '|'],
      ['\\a', '\a'],
      ['\\b', '\b'],
      ['\\f', '\f'],
      ['\\n', '\n'],
      ['\\r', '\r'],
      ['\\t', '\t'],
      ['\\v', '\v']
  ].freeze
  def start_server(server_id, hostname, server_port, username, password)
    $logger.info 'New Teamspeak Server starting.'
    @my_name = 'ts'
    @my_short = 'TS'
    @my_id = server_id

    #TODO: Das ist unschön. Hier sollte alles geladen werden
    #temporär lassen wir das so weil wir nur einen Channel pro Server unterstützen
    @@channels = Hash.new
    channel_name, user_id = @db.loadChannels(server_id).first

    begin
      ts = Teamspeak::Client.new(hostname, server_port)
      ts.login(username, password)
      ts.command('use sid=1', sid: 1)
      $logger.info 'New Teamspeak Server started.'

      #IDs beziehen
      @channel_id = ts.command("channelfind pattern=#{channel_name}", sid: 1)['cid']
      @@channels[@channel_id] = user_id
      whoami = ts.command("whoami", sid: 1)
      @my_ts_id = whoami['client_id']
      @my_username = whoami['client_login_name']

      #notify einrichten
      #ts.command("servernotifyregister event=textprivate", sid: 1)
      ts.command("servernotifyregister event=textchannel", sid: 1)
      #ts.command("servernotifyregister event=textserver", sid: 1)
      $logger.info "servernotifyregister ausgeführt!"

      #query in den zielchannel verschieben und umbenennen der query
      $logger.info ts.command("clientupdate client_nickname=bridge")
      $logger.info ts.command("clientmove clid=#{@my_ts_id} cid=#{@channel_id}")
    rescue Teamspeak::ServerError => e
      $logger.error e
      return #abbrechen
    end

    #Redis subscriben
    subscribe(@my_name)
    subscribe_cmd(@my_id)

    #Dieser Thread pollt den socket und empfängt Nachrichten
    Thread.new do
      begin
        loop do
          response = ''
          $logger.info "Polling socket"
          loop do
            response += ts.sock.gets
            break if response.index(' msg=')
          end
          $logger.info response
          $logger.info "Got response"
          parsed_response = parse_response(response)
          if parsed_response[0]['invokeruid'] != @my_username && !parsed_response[0]['invokername'].nil?
            self.publish(source_network_type: @my_short, source_network: @my_name,
                         nick: parsed_response[0]['invokername'],
                         message: parsed_response[0]['msg'],
                         user_id: @@channels[@channel_id])
          end
        end
      rescue StandardError => e
        $logger.error e
      end
    end

    #Dieser thread sendet Nachrichten
    Thread.new do
      loop do
        msg_in = @messages.pop
        unless msg_in.nil?
          begin
            $logger.debug "Got Textmessage from redis"
            if msg_in["message_type"] == 'msg'
              ts.command("sendtextmessage targetmode=2 target=#{@channel_id}",
                         {'sid' => 1, 'msg' => "[#{msg_in['source_network_type']}][#{msg_in['nick']}]#{msg_in['message']}"})
            else
              case msg_in["message_type"]
                when 'join'
                  ts.command("sendtextmessage targetmode=2 target=#{@channel_id}",
                             {'sid' => 1, 'msg' => "#{msg_in["nick"]} kam in den Channel"})
                when 'part'
                  ts.command("sendtextmessage targetmode=2 target=#{@channel_id}",
                             {'sid' => 1, 'msg' => "#{msg_in["nick"]} hat den Channel verlassen"})
                when 'quit'
                  ts.command("sendtextmessage targetmode=2 target=#{@channel_id}",
                             {'sid' => 1, 'msg' => "#{msg_in["nick"]} hat den Server verlassen"})
              end
            end
          rescue Exception => e
            $logger.info 'Failed to send Message'
            $logger.info e
            #theoretisch sollte sowas nicht nötig sein.
            #TODO: Wir müssen dringend Verbindungsverluste intern abfangen. Aber um Zeit zu sparen machen wir das
            Kernel.exit(1)
          end
        end
      end
    end
  end
  def parse_response(response)
    out = []
    response.split('|').each do |key|
      data = {}
      key.split(' ').each do |inner_key|
        value = inner_key.split('=', 2)
        data[value[0]] = decode_param(value[1])
      end
      out.push(data)
    end
    out
  end
  def decode_param(param)
    return nil unless param
    # Return as integer if possible
    return param.to_i if param.to_i.to_s == param
    SPECIAL_CHARS.each do |pair|
      param.gsub!(pair[0], pair[1])
    end
    param
  end
end

#server starting stuff
#wir müssen für jeden Server eine eigene Instanz der MumbleBridge erzeugen
ts_thread = Hash.new
db = DbManager.new
servers = db.loadServers('ts3')
$logger.debug servers
servers.each do |server|
  #ich habe keine ahnung wieso da felder nil sind
  unless server.nil?
    ts_thread[server['ID']] = Thread.new do
      begin
        $logger.info "Found config. Starting server. #{server}"
        ts = TeamspeakBridge.new
        ts.start_server(server['ID'], server['server_url'], server['server_port'], server['user_name'], server['user_password'])
      rescue StandardError => e
        $logger.debug 'Teamspeak crashed. Stacktrace follows.'
        $logger.debug e
      end
    end
  end
end

loop do
  sleep 10
end