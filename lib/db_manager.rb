require 'mysql2'
require 'yaml'
require 'logger'

#TODO: Hier muss noch mal alles durchgegangen werden und escaped werde
class DbManager
  def initialize
    @config = YAML.load_file(File.dirname(__FILE__) + '/../config.yml')[:database]
    @logger = Logger.new(File.dirname(__FILE__) + '/db_manager.log')
    @db = Mysql2::Client.new(:host => @config[:host], :username => @config[:user], :password => @config[:password])
    @db.select_db(@config[:database])
  end

  def loadChannels(server_id)
    #TODO: Ich glaub hier ist was kaputtgegangen
    # Server werden nicht mehr abgerufen
    #return false if !server_id.is_a? Fixnum
    channels = Hash.new
    @logger.info "Loading channels"
    res = @db.query("SELECT channel_name, user_ID FROM channels WHERE server_ID = #{server_id}")
    res.each do |entry|
      channels[entry['channel_name']] = entry['user_ID']
    end
    channels
  end

  def loadServers(server_type = nil, user_id = nil)
    servers = Array.new
    if !server_type.nil?
      query = "SELECT * FROM servers WHERE server_type LIKE '#{@db.escape(server_type)}'"
    elsif !user_id.nil?
      query = "SELECT * FROM servers WHERE user_ID = '#{@db.escape(user_id)}'"
    else
      query = "SELECT * FROM servers'"
    end

    res = @db.query(query)
    res.each do |entry|
      servers[entry['ID']] = entry
    end
    servers
  end

  #server hinzufügen. Im Grunde nur aliase für addServer
  def addJabberServer(server_url, server_port, username, password, user_id)
    addServer(server_url, server_port, 'jabber', username, password, user_id)
  end
  def addMumbleServer(server_url, server_port, username)
    addServer(server_url, server_port, 'mumble', username)
  end
  def addIRCServer(server_url, server_port, username)
    addServer(server_url, server_port, 'irc', username)
  end

  def addServer(server_url, server_port, server_type, user_name = 'bridge', user_password = 'NULL', user_id = 'NULL')
    server_port.to_int if server_port.respond_to?(:to_int)
    user_id = 'NULL' if user_id.nil?
    user_password = 'NULL' if user_password.nil?
    user_name = 'bridgie' if user_name.nil?
    sql = "INSERT INTO `servers` (`ID`, `user_ID`, `server_url`, `server_port`, `server_type`, `user_name`, `user_password`)
            VALUES (NULL, #{@db.escape(user_id)}, '#{@db.escape(server_url)}', '#{@db.escape(server_port)}', '#{@db.escape(server_type)}', '#{@db.escape(user_name)}', '#{@db.escape(user_password)}');"
    @logger.debug sql
    res = @db.query(sql)
    @logger.debug res
    #TODO: Reload starten oder planen
  end

  def getServerCount(user_id)
    @db.query("SELECT ID FROM servers WHERE user_ID = #{@db.escape(user_id)}").count
  end
  def getChannelCount(user_id, server_id = nil)
    if server_id.nil?
      @db.query("SELECT ID FROM servers WHERE user_ID = #{@db.escape(user_id)}").count
    else
      @db.query("SELECT ID FROM servers WHERE user_ID = #{@db.escape(user_id)} AND server_ID LIKE '#{@db.escape(server_id)}'").count
    end
  end
  def server_exists?(server_type, server_url, server_port)
    if @db.query("SELECT ID FROM servers WHERE server_type LIKE '#{@db.escape(server_type)}' AND server_url LIKE '#{@db.escape(server_url)}' AND server_url LIKE '#{@db.escape(server_url)}'").count > 0
      true
    end
  end
  def channel_exists?(user_id, server_id, channel_name)
    if @db.query("SELECT ID FROM channels WHERE user_ID = #{@db.escape(user_id)} AND server_ID = #{@db.escape(server_id)} AND channel_name LIKE '#{@db.escape(channel_name)}'").count > 0
      true
    end
  end
  def hasServer?(user_id, server_type)
    if ['telegram', 'irc'].include? server_type
      true
    else
      res = @db.query("SELECT ID FROM servers WHERE user_ID = #{@db.escape(user_id)} AND server_type LIKE '#{@db.escape(server_type)}'")
      if res.count > 0
        returntrue
      end
      false
    end
  end
  def userServers(user_id)
    return_vars = Hash.new
    res = @db.query("SELECT ID, server_url, server_port, server_type FROM servers WHERE user_ID = #{@db.escape(user_id)} OR user_ID IS NULL")
    res.each do |entry|
      return_vars[entry['ID']] = entry
    end
    return_vars
  end
  def userChannels(user_id)
    return_vars = Hash.new
    res = @db.query("SELECT ID, channel_name FROM channels WHERE user_ID = #{@db.escape(user_id)} OR user_ID IS NULL")
    res.each do |entry|
      return_vars[entry['ID']] = entry
    end
    return_vars
  end
  def valid_server?(server_id)
    res = @db.query("SELECT ID FROM servers WHERE ID = #{@db.escape(server_id)}")
    true if res.count > 0
  end

  def del_server(server_id)
    @db.query("DELETE FROM servers WHERE ID = #{@db.escape(server_id)}")
  end

  def del_channel(channel_id)
    @db.query("DELETE FROM channels WHERE ID = #{@db.escape(channel_id)}")
  end

  #check if user is allowed to use this server
  def allowed_server?(server_id, user_id = nil)
    if user_id.nil?
      res = @db.query("SELECT ID FROM servers WHERE ID = #{@db.escape(server_id)}")
    else
      res = @db.query("SELECT ID FROM servers WHERE ID = #{@db.escape(server_id)} AND (user_ID = '#{user_id}' OR user_ID IS NULL)")
    end
    true if res.count > 0
  end

  def allowed_channel?(channel_id, user_id)
    res = @db.query("SELECT ID FROM channels WHERE ID = #{@db.escape(channel_id)} AND user_ID = '#{user_id}'")
    true if res.count > 0
  end

  def getServerID(server_url, server_port)
    @db.query("SELECT ID FROM servers WHERE server_url LIKE '#{@db.escape(server_url)}' AND server_port LIKE '#{@db.escape(server_port)}'").fetch_hash['ID']
  end
  def blacklist
    return_vars = Hash.new
    res = @db.query('SELECT * FROM ignorelist')
    res.each do |entry|
      return_vars[entry['ID']] = entry
    end
    return_vars
  end

  #channel hinzufügen
  #für channel sind user_IDs pflicht. Anders können wir die nicht zuordnen
  def addChannel(user_id, server_id, channel, channel_password = nil)
    if (self.allowed_server?(server_id, user_id))
      channel_password.nil? ? channel_password = 'NULL' : channel_password = @db.escape(channel_password)
      sql = "INSERT INTO `channels` (`ID`, `user_ID`, `server_ID`, `channel_name`, `channel_password`)
              VALUES (NULL, '#{@db.escape(user_id)}', '#{@db.escape(server_id)}', '#{@db.escape(channel)}', #{channel_password})"
      res = @db.query(sql)
      @logger.info res
    end
    #TODO: Reload starten oder planen
  end

  #erzeugt einen neuen Datensatz für den User
  #generiert außerdem auch ein secret für die Datenbank
  def addUser(username, email = nil)
    email = 'NULL' if email.nil?
    secret = (0..31).map { (65 + rand(26)).chr }.join
    while !checkSecret(secret) do
      secret = (0..31).map { (65 + rand(26)).chr }.join
    end
    @db.query("INSERT INTO `users` (`ID`, `username`, `email`, `secret`) VALUES (NULL, '#{@db.escape(username)}', '#{@db.escape(email)}', '#{secret}');")
    secret #return the secret
  end

  def authUser(username, secret)
    res = @db.query("SELECT ID FROM `users` WHERE `username` LIKE '#{@db.escape(username)}' AND `secret` LIKE '#{@db.escape(secret)}'")
    @logger.info res
    if res.count > 0
      @logger.debug "Fetched ID: #{res.first['ID']}"
      res.first['ID']
    else
      false
    end
  end

  def checkSecret(secret)
    res = @db.query("SELECT * FROM `users` WHERE `secret` LIKE '#{secret}'")
    if res.count > 0
      return false
    end
    true
  end
end