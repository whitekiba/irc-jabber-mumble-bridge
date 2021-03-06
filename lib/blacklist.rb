require_relative '../lib/db_manager'

class Blacklist
  def initialize
    @blacklist = Hash.new
    @db = DbManager.new
    first_load
  end

  def blacklisted?(user_id, username)
    if !@blacklist[user_id].nil? && @blacklist[user_id].include?(username)
      return true
    end
    false
  end

  def sort_entrys(entrys)
    entrys.each_value do |entry|
      #neues Array element erstellen falls nicht existent
      if @blacklist[entry["user_ID"]].nil?
        @blacklist[entry["user_ID"]] = Array.new
      end
      @blacklist[entry["user_ID"]].push(entry["username"])
    end
  end

  def reload
    @blacklist = Hash.new
    first_load
  end

  def first_load
    blacklist_entrys = @db.blacklist
    self.sort_entrys(blacklist_entrys)
  end
end