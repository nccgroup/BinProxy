require_relative '../lib/binproxy/connection'

describe BinProxy::Connection::Filters::Socks do
  describe 'read client header' do
    before :each do
      @fake_conn = double
      allow(@fake_conn).to receive(:connect)
      # socks v4, open connection to 127.0.0.1:8080
      @header_data = [0x04, 0x01, 0x1f, 0x90, 127,0,0,1].pack('C*') + "asdf\0"
      @s = BinProxy::Connection::Filters::Socks.new(@fake_conn)
      @s.init
    end
    after :each do
      expect(@s.header.version).to eq(4) if @s.header
    end
    it 'reads all fields' do
      expect(@fake_conn).to receive(:connect)
      rest = @s.read(@header_data)
      expect(rest).to eq('')
    end
    it 'returns excess data' do
      expect(@fake_conn).to receive(:connect)
      rest = @s.read(@header_data + "zzz")
      expect(rest).to eq('zzz')
    end
    it 'passes through additional data' do
      expect(@fake_conn).to receive(:connect)
      @s.read(@header_data)
      expect(@s.read('moredata')).to eq('moredata')
    end
    it 'handles split headers' do
      rest1 = @s.read(@header_data[0..3])
      #TODO not happy about caring about nil vs empty here, but not in app
      expect(rest1).to eq(nil)
      expect(@fake_conn).to receive(:connect)
      rest2 = @s.read(@header_data[4..-1])
      expect(rest2).to eq('')
      expect(@s.read('aaa')).to eq('aaa')
    end
    it 'only connects after complete header' do
      @s.read(@header_data[0..-2])
      expect(@fake_conn).not_to receive(:connect)
    end
    it 'parses an IP address' do
      expect(@fake_conn).to receive(:connect).with('127.0.0.1', 8080)
      @s.read(@header_data)
    end
    it 'parses a v4a host name' do
      v4a_header = [0x04, 0x01, 0x1f, 0x90, 0,0,0,1].pack('C*') + "\0" + "example.com\0"
      expect(@fake_conn).to receive(:connect).with('example.com', 8080)
      @s.read(v4a_header)
    end
  end
end

