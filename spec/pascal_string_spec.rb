# encoding: binary
require_relative '../lib/binproxy/bd_util'

describe BinData::PascalString do
  context 'simple' do
    def test(args,str,bstr)
      ps = BinData::PascalString.new(*args).read(bstr + "trailing junk")
      expect(ps.snapshot).to eq str

      ps = BinData::PascalString.new(*args)
      ps.assign(str)
      expect(ps.to_binary_s).to eq bstr
    end
    it 'works with default param' do
      test([],'ABC',"\x03ABC")
      test([size_type: :uint8], 'ABC', "\x03ABC")
    end
    it 'works with int16' do
      test([size_type: :int16be], 'ABC', "\x00\x03ABC")
    end
  end
  # a bit crazier...
  it 'works with bits' do
    s = BinData::Struct.new(fields: [
        [:bit2, :a],
        [:pascal_string, :b, {size_type: :bit6}],
        [:stringz, :c] ])
    s.read("\xC5ABCDEXXXX\x00") #11000101 -> a=2, len=5
    expect(s.a).to eq 3
    expect(s.b).to eq 'ABCDE'
    expect(s.c).to eq 'XXXX'
  end
  it 'writes bits' do
    s = BinData::Struct.new(fields: [
      [:bit2, :before],
      [:pascal_string, :s, {size_type: :bit4}],
      [:bit4, :after]
    ])
    s.before= 0b11
    # two bits skipped
    s.s = 'ABCDE'
    s.after = 0b1010
    # four bits skipped
    expect(s.to_binary_s).to eq "\xD4ABCDE\xA0" #11 0101 00 ABCDE 1010 0000
  end
end
