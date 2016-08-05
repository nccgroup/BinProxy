require 'bindata'
class RawMessage < BinData::Record
  rest :data, display_as: 'hexdump'
end
