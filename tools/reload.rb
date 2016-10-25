require 'redis'
require 'json'

if !ARGV[0].nil?
  redis_cmd = Redis.new(:host => '127.0.0.1', :port => 7777)

  json = JSON.generate({
      'cmd' => 'reload',
      'args' => ''
                       })

  redis_cmd.publish("cmd.#{ARGV[0]}", json)
else
  puts "reload.rb <server type>"
end
