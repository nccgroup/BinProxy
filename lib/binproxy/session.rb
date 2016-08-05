module BinProxy
  # This class represents a pair of TCP connections (client <-> proxy and proxy
  # <-> server), through which a number of messages may be sent.
  class Session
    include Observable
    attr_reader :id, :endpoints, :open_time, :close_time

    def initialize(id, client, server, parser_class)
      @open_time = Time.now
      @id = id
      @endpoints = { client: client, server: server }
      p = parser_class.new
      @endpoints.each_pair do |peer, conn|
        conn.parser = p
        conn.add_observer(self, :send)
      end
    end

    # should receive a ProxyMessage from Connection
    def message_received(pm)
      pm.session = self
      changed
      notify_observers(:message_received, pm)
    end

    def send_message(message)
      endpoints[message.dest].send_message(message)
    end

    def connection_completed(conn)
      # this is only called for the upstream connection, as the downstream connection is already completed
      # by the time that the session is created
      log.warn 'unexpected connection_completed on downstream' if conn.peer != :server
      endpoints[:client].upstream_connected(conn)
    end

    def connection_lost(peer, reason)
      @close_time = Time.now
      # XXX Shutdown the endpoints
      #  - but not until we've finished passing through* any existing messages
      #  (this needs to be handled up a level at the proxy)
      #  * or dropping??
      changed
      notify_observers(:session_closed, self, peer, reason)
    end
  end
end
