# encoding: binary
require_relative '../lib/binproxy/bd_util'

describe BinData::Pointer do
  context 'simple' do
    before :all do
      str = "XXABC\x00\x02\xFEX"
      @r = BinData::Struct.new(fields: [
          [:uint16be, :x1],
          [:stringz, :s],
          [:pointer, :p, {ptr_type: :uint8, val_type: :stringz}],
          [:uint8, :x2] ]);
      @r.read(str)
    end
    it 'returns the pointed-to valuestring' do
      expect(@r.p).to eq 'ABC'
    end
    it 'leaves the stream in the correct place' do
      expect(@r.x2).to eq 0xFE
    end
  end
  context 'in a recursive record' do
    before :all do
      class RecRec < BinData::Record
        stringz :s
        uint8 :more
        pointer :p, ptr_type: :uint8, val_type: :rec_rec, seek_from: :raw_start, onlyif: lambda { more == 1 }
        uint8 :stuff
      end
    end
    it '(test the test)' do
      r = RecRec.read("Hello\x00\x00X")
      expect(r.snapshot[:s]).to eq 'Hello'
      expect(r.snapshot[:p]).to be_nil
      expect(r.stuff).to eq 'X'.ord
    end
    it 'doesn\'t blow up on recursion' do
      r = RecRec.read("AA\x00\x01\x06XBB\x00\x00Yabcdef\x00\x00\x00\x00")
      expect(r.s).to eq 'AA'
      expect(r.more).to eq 1
      expect(r.stuff).to eq 'X'.ord
      expect(r.p.s).to eq 'BB'
      expect(r.p.more).to eq 0
      expect(r.p.stuff).to eq 'Y'.ord
    end
    it 'has correct fields on recursion' do
      r = RecRec.read("AA\x00\x01\x06XBB\x00\x01\x0CYCC\x00\x00Zabcdef\x00\x00\x00\x00")
      expect(r.s).to eq 'AA'
      expect(r.more).to eq 1
      expect(r.stuff).to eq 'X'.ord
      expect(r.p.s).to eq 'BB'
      expect(r.p.more).to eq 1
      expect(r.p.stuff).to eq 'Y'.ord

      rpp = r.p[:p]
      expect(rpp.s).to eq 'CC'
      expect(rpp.more).to eq 0
      expect(rpp.stuff).to eq 'Z'.ord

      #XXX need to figure out why these aren't working.
      #expect(r.p.p.s).to eq 'CC'
      #expect(r.p.p.more).to eq 0
      #expect(r.p.p.stuff).to eq 'Z'.ord
    end
  end
end
