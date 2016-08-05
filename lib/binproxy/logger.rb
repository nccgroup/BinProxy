require 'logger'
module BinProxy; end
module BinProxy::Logger
  class BPLogger < Logger
    def err_trace(e, context = nil, level = Logger::ERROR)
      add level, "Error while #{context}:" if context
      add level, "#{e.class}: #{e.message}\n#{(e.backtrace - caller).join "\n"}"
    end
  end

  def log
    @@logger ||= BPLogger.new(STDOUT).tap do |log|
      log.level = Logger::WARN
    end
  end
  module_function :log
end
