#!/usr/bin/env ruby
Dir.chdir $pwd unless $pwd.nil?

$:.unshift("protocols/")

require "rubygems"
require "yaml"
require "logger"
#require './module_base'
require "redis"
require 'dummy_part'

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

loop do
  begin
    sleep 0.5
  rescue StandardError => e
    $logger.error e
    $logger.error e.backtrace.join("\n")
    bridge.broadcast(:core, " Unable to handle exception. Going down!")
    sleep 1
    abort
  end
end


# vim: tabstop=3
