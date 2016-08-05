# DNS Parser for BinProxy
#  use Dns::Packet class for UDP traffic, or Dns::TcpPacket for TCP.

require 'bindata'
require 'binproxy/bd_util'

module Dns

  class Header < BinData::Record
    endian :big

    uint16 :id
    bit1 :qr
    bit4 :opcode
    bit1 :aa
    bit1 :tc
    bit1 :rd
    bit1 :ra
    bit3 :z
    bit4 :rcode
    uint16 :qdcount
    uint16 :ancount
    uint16 :nscount
    uint16 :arcount
  end

  class NameElement < BinData::Record; end

  class NameSeq < BinData::Array
    default_parameter read_until: lambda { element.flag != 0x0 or element.val == '' }
    name_element
  end
  class NameElement < BinData::Record
    bit2 :flag
    choice :val, selection: :flag do
      pascal_string 0x0, size_type: :bit6
      pointer 0x3, ptr_type: :bit14, val_type: :name_seq, seek_offset: 2 #XXX
    end
  end

  class DnsRecord < BinData::Record
    endian :big
    name_seq :name
    uint16 :type
    uint16 :rclass
  end

  class Question < DnsRecord; end

  class ResourceRecord < DnsRecord
    uint32 :ttl
    uint16 :rdlength
    string :rdata, read_length: :rdlength
  end

  #XXX can't use Packet for UDP currently b/c of hardcoded 2 byte adjustment to pointers (due to length pre-header in TCP packets)
  class Packet < BinData::Record
    header :header
    array :questions,    type: :question,        initial_length: lambda { header.qdcount }
    array :answers,      type: :resource_record, initial_length: lambda { header.ancount }
    array :authorities,  type: :resource_record, initial_length: lambda { header.nscount }
    array :addl_records, type: :resource_record, initial_length: lambda { header.arcount }
  end


  class TcpPacket < BinData::Record
    uint16be :len
    packet :pkt
  end
end
