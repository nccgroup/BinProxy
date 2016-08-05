module BinProxy
  class ProxyBaseItem
    include BinProxy::Logger
    attr_accessor :session, :disposition, :id
    attr_reader :src, :dest, :time
    def src=(s)
      @src = s
      @dest = opposite_peer(s)
    end
    def dest=(d)
      @dest = d
      @src = opposite_peer(d)
    end

    def initialize
      @time = Time.now
    end

    def headers
      {
        message_id: @id,
        session_id: @session && @session.id,
        src: @src,
        dest: @dest,
        time: @time.to_i,
        disposition: @disposition,
      }
    end

    def to_hash
      { head: headers }
    end
    private

    def opposite_peer(p)
      case p
      when :client; :server
      when :server; :client
      else raise "invalid peer: #{p}"
      end
    end

  end
  class ProxyEvent < ProxyBaseItem
    def initialize(summary)
      super()
      @summary = summary
      @disposition = 'Info'
    end

    def headers
      super.merge({
        summary: @summary
      })
    end
  end
end
