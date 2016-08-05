# encoding: binary
require_relative '../lib/binproxy/bd_util'

describe BinData::Peek do
  it 'reads a byte' do
    p = BinData::Peek.read('A')
    expect(p.snapshot).to eq 'A'.ord
  end
  it 'reads bits' do
    p = BinData::Peek.new(type: :bit4).read("\xEF")
    expect(p.snapshot).to eq 0x0E
  end
  it 'reads two bytes' do
    p = BinData::Peek.new(type: :uint16be).read("\xAB\xCD")
    expect(p.snapshot).to eq 0xABCD
  end
  it 'reads a 3 byte string' do
    p = BinData::Peek.new(type: [:string, {read_length: 3}]).read('ABCZZZ')
    expect(p.snapshot).to eq 'ABC'
  end
  it 'consumes no bytes' do
    r = BinData::Struct.new(fields: [[:peek, :a, {type: :uint16be}], [:uint16be, :b]]).read("\xDE\xAD\xBE\xEF")
    expect(r.a).to eq 0xDEAD
    expect(r.b).to eq 0xDEAD
  end
  it 'raises on EOF' do
    io = BinData::IO::Read.new("too short")
    expect {
      BinData::Peek.new(type: [:string, {read_length: 99}]).read(io)
    }.to raise_error
    expect(io.offset).to eq 0
  end
end
