require 'stringio'
require 'observer'
require 'eventmachine'
require 'ipaddr'

require_relative 'proxy_message'
require_relative 'logger'
require_relative 'connection/filters'

module BinProxy
  # This module is included in an anonymous subclass of EM::Connection; each
  # instance represents a TCP connection between the proxy and the client or
  # server, so each Session has two Connections.
  module Connection
    include BinProxy::Logger
    include Observable

    attr_accessor :parser
    attr_reader :opts, :peer, :filters

    def initialize(opts)
      @opts = opts
      @peer = opts[:peer] # :client or :server
      @buffer = StringIO.new
      @filters = opts[:filter_classes].map do |c| c.new(self) end
    end

    def post_init
      @filters.each do |f|
        log.debug "initializing filter #{f}"
        f.init
      end
    end

    # Used by filters to initiate upstream connection in response to
    # inbound connection
    def connect(host=nil, port=nil, &cb)
      host ||= opts[:upstream_host] || raise('no upstream host')
      port ||= opts[:upstream_port] || raise('no upstream port')
      cb   ||= lambda { |conn| opts[:session_callback].call(self, conn) }
      log.debug "Making upstream connection to #{host}:#{port}"
      EM.connect(host, port, Connection, opts[:upstream_args], &cb)
    end

    # EM callback
    def connection_completed
      log.debug "connection_completed callback"
      changed
      notify_observers(:connection_completed, self)
    end

    # called by session
    def upstream_connected(upstream_conn)
      @filters.each do |f|
        f.upstream_connected(upstream_conn)
      end
    end

    def receive_data(data)
      @filters.each do |f|
        data = f.read data
        return if data.nil? or data == ''
      end

      @buffer.string << data #does not update @buffer's pos

      parser.parse @buffer, peer do |pm|
        log.debug "parsed proxy message: #{pm.inspect}"
        changed
        notify_observers(:message_received, pm)
      end

      if (pos = @buffer.pos) > 0
        @buffer.string = @buffer.string[pos .. -1] #resets pos to 0
      end


    rescue Exception => e
      puts e, e.backtrace
      raise e
    end

    # called with a ProxyMessage
    def send_message(pm)
      log.error "OOPS! message going the wrong way (to #{peer})" if pm.dest != peer

      data = pm.to_binary_s
      @filters.each do |f|
        data = f.write data
        return if data.nil? or data == ''
      end
      send_data(data)
    end

    def unbind(reason)
      log.debug "unbind called"
      changed
      notify_observers(:connection_lost, peer, reason)
    rescue Exception => e
      puts e, e.backtrace
      raise e
    end

  end
end
