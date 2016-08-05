require 'eventmachine'
require 'observer'
require 'bindata'
require 'active_support/core_ext/object/blank'
require_relative 'bindata'
require_relative 'connection'
require_relative 'session'
require_relative 'parser'
require_relative 'logger'

module BinProxy
  class Proxy
    include BinProxy::Logger
    include Observable
    attr_accessor :hold
    attr_reader :sessions
    attr_reader :buffer

    def initialize(root, opts)
      @class_loader = BinProxy::ClassLoader.new(root)
      @options = {}
      @sessions = []
      @buffer = []
      @filter_pids = []
      configure(opts)
    end

    def configure(new_opts = {})
      old_opts = @options.dup
      new_opts = old_opts.merge new_opts

      @hold = !! new_opts[:hold];
      @inbound_filters = []
      @upstream_filters = []

      if new_opts[:socks_proxy]
        @inbound_filters << BinProxy::Connection::Filters::Socks
      elsif new_opts[:http_proxy]
        @inbound_filters << BinProxy::Connection::Filters::HTTPConnect
      else
        @inbound_filters << BinProxy::Connection::Filters::StaticUpstream
      end

      if new_opts[:tls]
        @inbound_filters << BinProxy::Connection::Filters::InboundTLS
        @upstream_filters << BinProxy::Connection::Filters::UpstreamTLS
      end

      if new_opts[:debug_extra]
        @inbound_filters << BinProxy::Connection::Filters::Logger
        @upstream_filters << BinProxy::Connection::Filters::Logger
      end



      #XXX this reloads the class on every config change
      #XXX bad, but reloading in web console relies on it
      new_opts[:class] = @class_loader.load_class(new_opts[:class_name],new_opts[:class_file])
      if old_opts[:class] != new_opts[:class]
        @parser_class = Parser.subclass(self, new_opts[:class])
        @parser_class.validate = new_opts[:validate_parser]
      elsif new_opts[:class] == nil
        raise "Option :class must be specified"
      end

      [:lhost, :lport, :dhost, :dport].each do |o|
        # let people get away with it if it's already blank
        if old_opts[o].present? and new_opts[o].blank?
          raise "Option :#{o} must be specified"
        end
      end

      # This will not handle an exception if the server is started asynchronously, but
      # the only time that should happen is the initial configuration from command line args,
      # in which case we don't have existing opts to revert to anyway.
      begin
        @options = new_opts
        if old_opts[:lhost] != new_opts[:lhost] or old_opts[:lport] != new_opts[:lport]
          restart_server!
        end
      rescue Exception => e
        @options = old_opts
        raise e
      end
    end

    # XXX below is incorrect, we do call it on first configuration
    # We'll only call this internally if the server's host or port has changed; there's still the possiblility
    # that a quick a->b->a change, or manually calling this could fail because the OS hasn't released the port yet;
    # we'll punt on that for now, though.
    def restart_server!
      if stop_server!
        #server was indeed running
        #  TODO investigate whether this is actually necessary, or could be reduced/removed
        sleep 5
      end
      start_server!
    end

    def start_server!
      if EM.reactor_running?
        # Prefer to do this synchronously, so we can catch errors.
        start_server_now!
      else
        # Have to defer this until Sinatra/Thin starts EM running.
        EM.next_tick { start_server_now! }
      end
    end

    def stop_server!
      if @server_id
        @filter_pids.each do |pid|
          log.debug "Killing #{pid}"
          Process.kill "INT", pid  #TODO invstigate ncat signal handling
        end
        @filter_pids = [];
        Process.waitall
        EM.stop_server @server_id
        @server_id = nil
        true
      else
        false
      end
    end

    def status
      @server_id.nil? ? 'stopped' : 'running'
    end

    def history_size
      @buffer.length
    end

    def message_received(message)
      log.debug "proxy handling message_received"
      message.id = @buffer.length
      @buffer.push(message)

      if hold
        message.disposition = 'Held'
      else
        send_message(message, :auto)
      end

      changed
      notify_observers(:message_received, message)
    end

    def update_message_from_hash(hash)
      log.debug "updating message from hash"
      orig = @buffer[hash[:head][:message_id]]
      orig.update!(hash[:body][:snapshot])
      orig
    rescue Exception => e
      puts '', e.class, e.message, e.backtrace, ''
      on_bindata_error('deserialization', e)
    end

    def send_message(message, reason)
      log.debug "proxy.send_message #{message.inspect}"
      message.forward!(reason)
    rescue Exception => e
      puts '', e.class, e.message, e.backtrace, ''
      on_bindata_error('forwarding', e)
    end

    def drop_message(message, reason)
      log.debug "proxy.drop_message #{message.inspect}"
      message.drop!(reason)
    rescue Exception => e
      puts '', e.class, e.message, e.backtrace, ''
      on_bindata_error('dropping', e)
    end

    def session_closed(session, closing_peer, reason)
      pe = BinProxy::ProxyEvent.new("Connection closed (#{reason||'no error'})")
      pe.id = @buffer.length
      pe.src = closing_peer
      pe.session = session
      @buffer.push(pe)

      session.delete_observer(self)
      changed
      notify_observers(:session_event, pe)
    end

    def ssl_handshake_completed(session, peer)
      changed
      notify_observers(:ssl_handshake_completed, session, peer)
    end

    def on_bindata_error(operation, err)
      changed
      notify_observers(:bindata_error, operation, err)
    end

    private
    def create_session(inbound_conn, upstream_conn)
      id = @sessions.length
      session = Session.new(id, inbound_conn, upstream_conn, @parser_class)
      session.add_observer(self, :send)
      @sessions << session

      pe = BinProxy::ProxyEvent.new "Connection opened"
      pe.id = @buffer.length
      pe.src = :client
      pe.session = session
      @buffer.push(pe)

      changed
      notify_observers(:session_event, pe)
    rescue Exception => e
      puts e, e.backtrace
    end

    def start_server_now!
      lhost = @options[:lhost]
      lport = @options[:lport].to_i #force port to_i, or EM may assume different method signature

      #These may be nil and are ignored in socks mode
      dhost = @options[:dhost]
      dport = @options[:dport].to_i

      log.info "(re)starting proxy on #{lhost}:#{lport}"
      upstream_args = {
        peer: :server,
        filter_classes: @upstream_filters
      }
      inbound_args = {
        peer: :client,
        session_callback: self.method(:create_session),
        tls_args: { cert_chain_file: @options[:tls_cert], private_key_file: @options[:tls_key] },
        filter_classes: @inbound_filters,
        upstream_host: dhost,
        upstream_port: dport,
        upstream_args: upstream_args
      }
      @server_id = EM.start_server(lhost, lport, Connection, inbound_args)
    end

  end
end
