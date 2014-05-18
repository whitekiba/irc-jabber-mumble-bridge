#!/usr/bin/env ruby19

require 'rubygems'
require 'daemons'

$pwd = File.dirname(File.expand_path(__FILE__))

options = {
  app_name: 'bridge'
}

Daemons.run('bridge.rb')
