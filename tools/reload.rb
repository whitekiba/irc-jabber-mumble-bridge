require 'redis'
require 'json'

redis_cmd = Redis.new(:host => "127.0.0.1", :port => 7777)

json = JSON.generate({
    'cmd' => 'reload',
    'args' => ''
                     })

redis_cmd.publish('cmd.irc', json)