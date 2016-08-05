require 'bindata'
class FailClass < BinData::Record
  def read(io)
    raise StandardError.new("kaboom")
  end
end
