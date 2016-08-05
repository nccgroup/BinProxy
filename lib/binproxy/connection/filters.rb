module BinProxy::Connection; end
module BinProxy::Connection::Filters
  class Base
    attr_reader :conn
    def initialize(connection)
      @conn = connection
    end

    def init; end
    def upstream_connected(upstream_conn); end
    def session_closing(reason); end

    def read(data); data; end
    def write(data); data; end
  end

  # Fortunately, we don't have to implement TLS ourself, just tell EM to
  # use it on opening the connection.
  #
  # TODO: The "magical" nature of the start_tls connection upgrade doesn't play
  # well with the filter concept, data might be buffered into filters before
  # start_tls happens.  There's also no way to do STARTTLS-like protocols that
  # pass plaintext data all the way through.
  class InboundTLS < Base
    include BinProxy::Logger
    def init
      @state = :new
    end
    def upstream_connected(upstream_conn)
      #TODO no way to set tls_args for upstream connection currently
      conn.start_tls(conn.opts[:tls_args]||{})
      @state = :tls
    end
    def read(data)
      if @state != :tls
        #XXX we might want this in the case of STARTTLS?
        log.fatal "DATA RECEIVED BY FILTER BEFORE START_TLS #{conn}"
      end
      data
    end
  end
  class UpstreamTLS < Base
    def init
      #TODO no way to set tls_args for upstream connection currently
      conn.start_tls(conn.opts[:tls_args]||{})
    end
  end

  class Logger < Base
    include BinProxy::Logger
    def init
      log.debug "CONNECTION CREATED #{conn}"
    end
    def read(data)
      log.debug "READ #{conn}\n#{data.hexdump}"
      data
    end
    def write(data)
      log.debug "WRITE #{conn}\n#{data.hexdump}"
      data
    end
  end

  class StaticUpstream < Base
    def init
      conn.connect
    end
  end

  class Socks < Base
    SOCKS_OK =  "\x00\x5a" + "\x00" * 6
    SOCKS_ERR = "\x00\x5b" + "\x00" * 6
    include BinProxy::Logger
    attr_reader :socks_state, :header
    class ClientHeader < BinData::Record #TODO just handles v4/v4a for now
      uint8 :version
      uint8 :command_code
      uint16be :port
      uint32be :ip
      stringz :user
      stringz :host, onlyif: :bogus_ip?

      def host_or_ip
        if host? then host else IPAddr.new(ip, Socket::AF_INET).to_s end
      end

      def bogus_ip?
        # an IP value of 0.0.0.x (x > 0) is a SOCKSv4a flag for server-side DNS.
        ip > 0 && ip <= 255
      end
    end
    def init
      @buf = StringIO.new
      @state = :new
    end
    def read(data)
      return data unless @state == :new

      @buf.string << data
      @header = ClientHeader.read(@buf)

      # no exception means we've read a full header...
      log.debug "Read SOCKS header #{@header}"
      @state = :connecting

      conn.connect @header.host_or_ip, @header.port

      # return any extra data
      @buf.read
    rescue EOFError, IOError
      #partial read of header, reset to try again on next packet
      @buf.pos = 0
      nil
    rescue EM::ConnectionError => e
      #synchronous error when connecting upstream, e.g. bogus hostname
      log.warn "Can't connect to '#{@header.host_or_ip}': #{e.message}"
      #TODO -close the connection
      nil
    end
    def upstream_connected(upstream_conn)
      log.error "unexpected upstream_connected in state #{@state}" unless @state == :connecting
      @state = :connected
      conn.send_data SOCKS_OK
    end
    def session_closing(reason)
      conn.send_data SOCKS_ERR if @state == :connecting
    end
  end

  #TODO - lots of copy-paste from SOCKS, could stand to refactor
  class HTTPConnect < Base
    include BinProxy::Logger
    def init
      @buf = StringIO.new
      @state = :new
    end
    def read(data)
      log.debug "HTTPConnect read data #{data.inspect} in state #{@state}"
      return data if @state == :connected
      raise "unexpected data while connecting" if @state == :connecting

      #append, but keep current position
      p = @buf.pos
      @buf << data
      @buf.pos = p

      while line = @buf.gets #XXX assumes we get whole lines
        log.debug "processing line #{line}, state=#{@state}"
        case @state
        when :new
          if m = line.match( %r<\ACONNECT ([\w.-]+):(\d+) HTTP/1.1\r\n\z> )
            @host, @port = m[1], m[2]
            @state = :headers
            log.debug "Got CONNECT message to #{@host}:#{@port}"
          else
            log.warn "expected a CONNECT request, got #{line.inspect}"
          end
        when :headers
          if line == "\r\n"
            log.debug "End of CONNECT headers"
            @state = :connecting
            conn.connect @host, @port
            return nil #XXX TODO confirm that @buf is empty
          else
            log.debug "Extra header on CONNECT: #{line.inspect}"
          end
        else
          log.fatal "HTTPConnect filter in bad state: #{@state}"
        end
      end
      log.debug "loop terminated with line #{line.inspect}"

      #not done with CONNECT yet
      nil
    rescue EM::ConnectionError => e
      #synchronous error when connecting upstream, e.g. bogus hostname
      log.warn "Can't connect to '#{m[1]}:#{m[2]}': #{e.message}"
      #TODO -close the connection
      nil
    end
    def upstream_connected(upstream_conn)
      log.error "unexpected upstream_connected in state #{@state}, conn=#{conn}" unless @state == :connecting
      @state = :connected
      conn.send_data "HTTP/1.1 200 BINPROXY OK\r\n\r\n"
    end
    def session_closing(reason)
      conn.send_data "HTTP/1.1 502 BINPROXY FAIL\r\n\r\n" if @state == :connecting
    end
  end
end
