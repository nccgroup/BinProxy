# encoding: binary

require 'json'
require_relative '../lib/binproxy/proxy_message'
DEBUG=false

class R < BinData::Record
  endian :little
  uint8 :i
  stringz :str
end

describe BinProxy::ProxyMessage do
  describe '(init)' do
    it 'is instantiated' do
    s1 = "\x01one\x00"
    pm = BinProxy::ProxyMessage.new(s1, R.read(s1))
    expect(pm).to be_a(BinProxy::ProxyMessage)
    end
  end
  describe '#update!' do
    subject { @pm1.message.str }
    before :each do
      s1 = "\x01one\x00"
      @pm1 = BinProxy::ProxyMessage.new(s1, R.read(s1))
      @ss1 = @pm1.to_hash[:body][:snapshot]

      s2 = "\x02two\x00"
      @pm2 = BinProxy::ProxyMessage.new(s2, R.read(s2))
      @ss2 = @pm2.to_hash[:body][:snapshot]
    end
    it 'round trips as a hash' do
      @pm1.update!(@ss2)
      expect(subject).to eq('two')
    end
    it 'round trips w/ string names (hash->json->hash)' do
      json = JSON.generate(@ss2)
      ss2a = JSON.parse(json, symbolize_names: true)
      @pm1.update!(ss2a)
      expect(subject).to eq('two')
    end
  end
end
__END__

r = R.new.read("\xFFhello\x00")
puts r.annotated_snapshot

puts deannotate_snapshot(r.annotated_snapshot)
r2 = R.new
r2.assign(deannotate_snapshot(r.annotated_snapshot))

p r
p r2

p r.to_binary_s
p r2.to_binary_s

require '../parsers/x11_proto'
x1 = X11Proto.new src: 'client', protocol_state: X11Proto.initial_state
p x1.snapshot
p deannotate_snapshot(x1.annotated_snapshot)
