require_relative 'logger'

module BinProxy
  class Parser
    include BinProxy::Logger

    class << self
      attr_accessor :proxy, :message_class, :validate
    end
    def message_class; self.class.message_class; end
    def validate; self.class.validate; end

    def self.subclass(proxy, mc)
      unless mc.class == Class
        BinProxy::Logger::log.fatal "#{mc} is a #{mc.class}, not a Class."
        exit!
      end
      c = Class.new(self) do
        @proxy = proxy #XXX I don't love the tight coupling here; need a better way to pass messages up the chain
        @message_class = mc
      end
    end

    def initialize
      @protocol_state = message_class.initial_state
    rescue => e
      log.warn "Exception while getting initial state for #{message_class}: e"
      if e.message.match /undefined method `initial_state'/ then
        log.warn "This is possibly not a subclass of BinData::Base"
      end
      # try to proceed with a default value
      BinData::Base.initial_state
    end

    # Try to parse one or more messages from the buffer, and yield them
    def parse(raw_buffer, peer)
      start_pos = nil
      loop do
        break if raw_buffer.eof?

        start_pos = raw_buffer.pos

        log.debug "at #{start_pos} of #{raw_buffer.length} in buffer"

        read_fn = lambda { message_class.new(src: peer.to_s, protocol_state: @protocol_state).read(raw_buffer) }

        message = if log.debug?
          BinData::trace_reading &read_fn
        else
          read_fn.call
        end

        bytes_read = raw_buffer.pos - start_pos
        log.debug "read #{bytes_read} bytes"

        # Go back and grab raw bytes for validation of serialization
        raw_buffer.pos = start_pos
        raw_m = raw_buffer.read bytes_read

        @protocol_state = message.update_state
        log.debug "protocol state is now #{@protocol_state.inspect}"

        pm = ProxyMessage.new(raw_m, message)
        pm.src = peer
        yield pm
      end
    rescue EOFError, IOError
      log.info "Hit end of buffer while parsing.  Consumed #{raw_buffer.pos - start_pos} bytes."
      raw_buffer.pos = start_pos #rewind partial read
      #todo, warn to client if validate flag set?
    rescue Exception => e
      log.err_trace(e, 'parsing message (probably an issue with user BinData class)', ::Logger::WARN)
      self.class.proxy.on_bindata_error('parsing', e)
    end
  end
end
