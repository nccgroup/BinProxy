require 'sinatra/base'
require 'sinatra-websocket'
require 'clipboard'

# Currently, the caller passes a block to .new which configures the Sinatra
# app.  this config applies to the whole class, so technically we should
# probably use some sort of get_instance class method which builds a subclass
# for each invocation, but YAGNI.

class BinProxy::WebConsole < Sinatra::Base
  include BinProxy::Logger

  def self.new_instance(&blk)
    c = Class.new(self)
    c.configure &blk
    c.new
  end

  #def initialize
  #  raise RuntimeError.new "Use WebConsole.build(&blk) instead of .new" if self.class == BinProxy::WebConsole
  #  super
  #end

  set sockets: []
  set haml: { escape_html: true }

  get '/' do
    if request.websocket?
      request.websocket {|s| WebSocketHandler.new(settings.proxy, s) }
    elsif settings.proxy.status != 'running'
      redirect '/config'
    else
      haml :index, locals: {need_config: settings.proxy.nil?}
    end
  end

  get '/config' do
    haml :config, locals: { opt_vals: settings.opts }
  end

  post '/config' do
    params.symbolize_keys!
    new_opts = settings.opts.merge params
    begin
      settings.opts = new_opts
      settings.proxy.configure(new_opts)
      redirect '/'
    rescue Exception => e
      log.err_trace(e, 'updating configuration')
      haml :config, locals: { opt_vals: new_opts, err_msg: e.message }
    end
  end

  post '/reload' do
    content_type :json
    begin
      settings.proxy.configure(settings.opts) #XXX this relies on configure to always trigger reload
      { success: true }.to_json
    rescue Exception => e
      { success: false, message: e.message, detail: e.backtrace.join("\n") }.to_json
    end
  end

  put '/clipboard' do
    content_type :json
    begin
      if Clipboard.implementation == Clipboard::File
        return { success: false, message: "Clipboard not available.  Install xclip?" }.to_json
      end
      log.info "Copying #{request.content_length} bytes to clipboard"
      text = request.body.read
      log.debug "CB Data: #{text}"
      Clipboard.copy text
      { success: true }.to_json
    rescue Exception => e
      log.error e.message + ": " + e.backtrace.join("\n")
      { success: false, message: e.message, detail: e.backtrace.join("\n") }.to_json
    end
  end

  get '/:name.css' do
    begin
      scss params[:name].to_sym, style: :expanded
    rescue Sass::SyntaxError => e
      log.err_trace(e, 'processing SCSS stylesheet')
      content_type :css
      "body::before { color: red; content: 'SASS Error: #{e.message} : #{e.backtrace[0]}' }"
    end
  end

  get '/m/:id' do
    content_type :json
    settings.proxy.buffer[params[:id].to_i].to_hash.to_json rescue 404
  end

  class WebSocketHandler
    include BinProxy::Logger

    def initialize(proxy, socket)
      @proxy = proxy
      @socket = socket
      @pending_messages = []

      socket.onopen { self.onopen }
      socket.onmessage {|m| self.onmessage(m) }
      socket.onclose { self.onclose }
    end

    def socket_send(type, data)
      @socket.send( JSON.generate({
        type: type,
        data: data
      }, max_nesting: 99)) #XXX
    end

    def onopen
      @proxy.add_observer(self, :send)
      socket_send :message_count, @proxy.history_size
    end

    def onmessage(raw_ws_message)
      log.debug "websocket message received: #{raw_ws_message}"
      ws_message = JSON.parse(raw_ws_message, symbolize_names: true)
      case ws_message[:action]
      when 'ping'
        socket_send :pong, status: @proxy.status
      when 'forward'
        message = @proxy.update_message_from_hash(ws_message[:message])
        @proxy.send_message(message, :manual)
        socket_send :update, message.to_hash #XXX send all of this, or just update?
      when 'drop'
        #XXX just doing this to get the message object
        message = @proxy.update_message_from_hash(ws_message[:message])
        @proxy.drop_message(message, :manual)
        socket_send :update, message.to_hash #XXX same as above
      when 'setIntercept'
        log.debug "setIntercept: #{ws_message[:value]}"
        @proxy.hold = ws_message[:value]
      when 'load'
        log.debug "load: #{ws_message[:value]}"
        socket_send_message @proxy.buffer[ws_message[:value]]
      when 'getHistory'
        log.error 'unexpected getHistory'
      #  log.debug "getHistory"
      #  @proxy.buffer.each do |message|
      #    socket_send_message message
      #  end
      when 'reloadParser'
        log.debug 'reloadParser'
        begin
          @proxy.configure #XXX this relies on configure to always trigger reload, which is considered a bug
          socket_send :info, message: 'Parser Reloaded'
        rescue Exception => e
          socket_send :error, message: "Parser Reload Failed: #{e.message}", detail: e.backtrace
          log.err_trace(e, 'Reloading Parser')
        end
      else
        log.error 'Unexpected WS message: ' + ws_message.inspect
      end
      log.debug 'Finished processing WS message'
    #rescue Exception => e
    #  puts "caught #{e}", e.backtrace
    end

    def onclose
      @proxy.delete_observer(self)
    #rescue Exception => e
    #  puts "caught #{e}", e.backtrace
    end

    def message_received(message)
      log.debug "sending WS message to front-end for message #{message.id}"
      socket_send_message message
    end

    def session_event(event)
      log.debug "session event #{event}"
      socket_send :event, event.to_hash
      #TODO delete observer if event is connection close
    end

    def bindata_error(operation, err)
      socket_send :error, {
        message: "Internal Error in #{operation}: #{err.class}: #{err.message}",
        detail: err.backtrace.join("\n")
      }
    end

    private
    def socket_send_message(message)
      socket_send :message, message.to_hash
    end
  end
end
