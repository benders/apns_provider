## Notification
## 
## Based on Fabien Penso's original Ruby on Rails source
## Updated by Anton Kiland (april 2009)
## 
## Requires json (sudo gem install json)
## Usage:
## notification = Apns.new(device_token)
## notification.alert = 'Hello World!'
## notification.badge = 10
## notification.sound = 'purr.caf'
## notification.send_notification
##
## If you want to send multiple notifications in the same session use:
## Apns.send_notifications([notification1, notification2, notification3])
##
## Protected under Apple iPhone Developer NDA
##

require 'rubygems'

require 'socket'
require 'openssl'
require 'json'

module Apns
  class Notification

    attr_accessor :sound, :badge, :alert, :app_data
    attr_reader :device_token

    def initialize(token)
      @device_token = token
    end

    def apn_message_for_sending
      json = to_apple_json
      "\0\0#{device_token_bytes.length.chr}#{device_token_bytes}\0#{json.length.chr}#{json}"
    end

    protected

    def to_apple_json
      self.apple_array.to_json
    end

    def device_token_bytes
      [self.device_token.delete(' ')].pack('H*')
    end

    def apple_array
      result = {}
      result['aps'] = {}
      result['aps']['alert'] = alert if alert
      result['aps']['badge'] = badge if badge
      result['aps']['sound'] = sound if sound
      result.merge!(app_data) if app_data
      result
    end
  end

  class Client
    HOST = 'gateway.sandbox.push.apple.com'
    PATH = '/'
    PORT = 2195
    CERTFILE = File.join(File.dirname(__FILE__), '..', 'config', 'apple_push_notification.pem')
    CERT = File.read(CERTFILE) if File.exists?(CERTFILE)
    PASSPHRASE = ''

    def initialize(environment = :sandbox)
      @socket, @ssl = ssl_connection
    end

    def send_notification( n )
      @ssl.write(n.apn_message_for_sending)
    rescue SocketError => error
      raise "Error while sending notification: #{error}"
    end

    def send_notifications (notifications)
      notifications.each do |notification|
        @ssl.write(notification.apn_message_for_sending)
      end
    rescue SocketError => error
      raise "Error while sending notifications: #{error}"
    end

    protected

    def ssl_connection
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.key = OpenSSL::PKey::RSA.new(CERT, PASSPHRASE)
      ctx.cert = OpenSSL::X509::Certificate.new(CERT)

      s = TCPSocket.new(HOST, PORT)
      ssl = OpenSSL::SSL::SSLSocket.new(s, ctx)
      ssl.sync = true
      ssl.connect

      return s, ssl
    end
  end
end