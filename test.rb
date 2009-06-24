#!/usr/bin/env ruby -wKU
$LOAD_PATH << File.dirname(__FILE__)

require 'rubygems'
require 'memcache'

require 'active_support/core_ext/hash/keys'
class Hash
  include ActiveSupport::CoreExtensions::Hash::Keys
end

def config
  config_path = File.join(File.dirname(__FILE__), 'config', 'apns.yml')
  @@config ||= YAML.load_file(config_path).symbolize_keys
  @@config
rescue
  STDERR.puts "Could not load config: #{$!}"
  exit!
end

starling = MemCache.new(config[:starling_addr])

token = ARGV[0].downcase.gsub(/[^0-9a-f]/, '')
num = rand(99)

notification = {
  :badge => num,
  :sound => 'default',
  :alert => "I just set your badge to #{num}",
  # :app_data => {:URL => 'http://yourmom.com'},
  :device_token => token
}

if (starling.stats rescue nil)
  STDOUT.puts "Sending via Starling"
  starling.set 'to_apns', notification
else
  STDOUT.puts "Starling not available, sending direct"
  require 'lib/apns'
  n = Apns::Notification.new( notification[:device_token] )
  n.badge = notification[:badge]
  Apns::Client.new(:sandbox).send_notification( n )
end
