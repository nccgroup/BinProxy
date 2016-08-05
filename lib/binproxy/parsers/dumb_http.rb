# A stupid HTTP BinData class to demonstrate the proxy
require_relative '../bd_util'

module DumbHttp
  class Headers < BinData::Array 
    default_parameter read_until: lambda { element == '' }
    line line_end: "\r\n"
  end

  class BaseMessage < BinData::Record
    headers :headers

    def body_len
      (headers.snapshot.grep(/\AContent-Length: (\d+)/) { $1.to_i }).first || 0
    end

    def summary; headers.first.sub(/HTTP\/\d\.\d/,'').strip; end
  end

  class Message < BaseMessage
    string :body, display_as: 'multiline', onlyif: lambda { body_len > 0 }, length: :body_len
  end

  class BinMessage < BaseMessage
    string :body, display_as: 'hexdump', onlyif: lambda { body_len > 0 }, length: :body_len
  end

end
