#!/usr/bin/env ruby -wKU
$LOAD_PATH << File.dirname(__FILE__)

require 'rubygems'

# require 'main'
require 'eventmachine'
require 'memcache'
require 'logger'

require 'active_support/core_ext/hash/keys'
class Hash
  include ActiveSupport::CoreExtensions::Hash::Keys
end

require 'lib/apns'

# set up logger
# ApnsGateway.logger = Logger.new(File.join(File.dirname(__FILE__), 'apns_gateway.log'))
# ApnsGateway.logger.formatter = Logger::Formatter.new
$logger = Logger.new(STDERR)

INCOMING_QUEUE = 'to_apns'

def logger
  $logger
end

def config
  config_path = File.join(File.dirname(__FILE__), 'config', 'apns.yml')
  @@config ||= YAML.load_file(config_path).symbolize_keys
  @@config
rescue
  logger.fatal "Could not load config: #{$!}"
  exit!
end

class EmHandler < EventMachine::Connection
  def initialize(config, channel)
    @config = config
    @channel = channel
  end

  def connection_completed
    start_tls(:private_key_file => File.join(File.dirname(__FILE__), 'config', @config[:key_file]), 
      :cert_chain_file => File.join(File.dirname(__FILE__), 'config', @config[:cert_file]),
      :verify_peer => false)
  end

  def ssl_handshake_completed
    logger.info "SSL Session Established"
    # logger.debug "Got Peer Certificate:\n" + get_peer_cert
    @sid = @channel.subscribe do |x|
      logger.debug "Sending: #{x.inspect}"
      send_data(x)
    end
  end

  def unbind
    @channel.unsubscribe @sid
    EventMachine::stop_event_loop
  end
end

def start(config)
  logger.debug "Entering Start method."

  channel = EM::Channel.new
  starling = MemCache.new(config[:starling_addr])

  # Run EventMachine in loop so we can reconnect when the SMSC drops our connection.
  loop do

    #
    # Main EM Block
    #
    EventMachine::run do
      logger.info "Attempting to connect to APNS"
      
      EventMachine::connect( config[:host], config[:port], EmHandler, config, channel)
      
      # This block will be called periodically to poll the Starling queue
      EventMachine::add_periodic_timer(1) do
        to_send = starling.get(INCOMING_QUEUE)
        if to_send
          logger.info "Received message: #{to_send.inspect}"
          begin
            n = Apns::Notification.new(to_send[:device_token])
            n.alert = to_send[:alert]
            n.badge = to_send[:badge]
            n.sound = to_send[:sound]
            n.app_data = to_send[:app_data]
            channel << n.apn_message_for_sending
          rescue Exception => ex
            logger.error "Error queuing Notification: #{ex} #{ex.backtrace[0]}"
          end
        end
      end

    end
    #
    # End Main EM Block
    #
    
    if $exiting
      logger.info "Exiting"
      break
    else
      logger.warn "Event loop stopped. Restarting in 5 seconds.."
      sleep 5
    end
  end
end

def shutdown
  logger.warn "Shutting down on SIGINT"
  $exiting = true
  # $tx.send_unbind if $tx.state == :bound
  # sleep 5
  EventMachine::stop_event_loop
end



trap("INT") { shutdown }

# Start the Gateway
begin   
  logger.info "Starting APNS Gateway"  
  start(config)  
rescue Exception => ex
  logger.fatal "Exception in APNS Gateway: #{ex} at #{ex.backtrace[0]}"
end
