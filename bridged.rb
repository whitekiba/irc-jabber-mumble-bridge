#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

$pwd = File.dirname(File.expand_path(__FILE__))

options = {
  :app_name => 'bridge',
  :monitor	=>	true
}

Daemons.run('bridge.rb', options)
