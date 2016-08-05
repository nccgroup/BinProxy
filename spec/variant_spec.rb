# encoding: binary
require_relative '../lib/binproxy/bd_util'

=begin

I have commented out Variant, as there doesn't seem to be any
good way to use it within a DSL class, which was the main
reason for it.

context BinData::Variant do
  it 'could be a byte' do
    vb = BinData::Variant.new(type: :uint8)
    vb.read("ABC")
    expect(vb.snapshot).to eq 0x41
  end
  it 'could be a stringz' do
    vs = BinData::Variant.new(type: :stringz)
    vs.read("ABC\x00D")
    expect(vs.snapshot).to eq 'ABC'
  end
  it 'does writes' do
    vb = BinData::Variant.new(type: :uint8)
    vb.assign(0xFF)
    expect(vb.to_binary_s).to eq "\xFF"
  end
end
=end
