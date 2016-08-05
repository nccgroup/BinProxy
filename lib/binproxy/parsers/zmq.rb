# ZeroMQ (ZMTPv3) Parser for BinProxy

module ZMQ
  # this greeting1/2/3 business is due to the fact that
  # zmq sends the greeting in parts and waits for the reply
  # from the other endpoint in order to do version detection.
  class Greeting1 < BinData::Record
    uint8 :sig_start, asserted_value: 0xFF
    string :sig_padding, length: 8
    uint8 :sig_end, asserted_value: 0x7F
  end

  class Greeting2 < BinData::Record
    uint8 :version_major, asserted_value: 0x03
  end

  class Greeting3 < BinData::Record
    uint8 :version_minor, asserted_value: 0x00

    string :mechanism, length: 20

    uint8 :as_server

    string :filler, length: 31 #pad to 64 bytes
  end

  class Frame < BinData::Record
    bit5 :reserved
    bit1 :is_command
    bit1 :is_long
    bit1 :has_more
    choice :body_size, selection: :is_long, display_as: 'anon' do
      uint8    0
      uint64be 1
    end
    string :body, read_length: :body_size
  end

  class Message < BinData::Record
    # States are (G)reeting 1/2/3 (see above), (H)andshake, and (T)raffic.
    def next_state(s); {'G1'=>'G2','G2'=>'G3','G3'=>'H', 'H'=>'T', 'T'=>'T'}[s]; end
    def self.initial_state; {'client'=>'G1','server'=>'G1'}; end

    # Protocol is symmetrical.  Each endpoint has its own state.
    # This is a bit clunky and maybe should be abstracted into a module?
    # Or update parser.rb to differentiate between proto-shared and endpoint-separate state?
    def update_state
      current_state.dup.tap do |s|
        src = eval_parameter :src
        s[src] = next_state s[src]
      end
    end

    choice :msg_type, selection: lambda { current_state[eval_parameter(:src) ] }, display_as: 'anon' do
      greeting1  'G1'
      greeting2  'G2'
      greeting3  'G3'
      frame 'H' #contains a command w/ arbitrary content
      frame 'T' #can contain command or message
    end
  end
end
