require 'bindata'
require_relative '../lib/binproxy/bindata'
require_relative '../lib/binproxy/proxy_message'
class BinProxy::ProxyMessage
  public :deannotate_snapshot
end

class R < BinData::Record
  endian :little
  uint8 :a
  stringz :b
  struct :foo do
    uint8 :c
    uint8 :d
    struct :baz do
      uint8 :n
      uint8 :m
    end
  end
  array :bar, initial_length: 3 do
    uint8 :e
  end
  rest :z
end

DEBUG = false
pm = BinProxy::ProxyMessage.new(nil,nil);


r = R.new.read("\xFFhello\x00\xEE\xDD\xCC\xBB\x01\x02\x04asdf")
puts r.annotated_snapshot

puts r 
puts '---'

puts pm.deannotate_snapshot(r.annotated_snapshot)
r2 = R.new
r2.assign(pm.deannotate_snapshot(r.annotated_snapshot))

p r
p r2

p r.to_binary_s
p r2.to_binary_s
__END__
require '../parsers/x11_proto'

x1 = X11Proto.new src: 'client', protocol_state: X11Proto.initial_state
p x1.snapshot 
p deannotate_snapshot(x1.annotated_snapshot)
