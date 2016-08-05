require 'bindata'

module X11
end

class X11SetupReq < BinData::Record
  endian :little #totally cheating here!
  uint8 :byte_order
  skip length: 1
  uint16 :proto_major
  uint16 :proto_minor
  uint16 :auth_proto_name_len, value: lambda { auth_proto_name.length }
  uint16 :auth_proto_data_len, value: lambda { auth_proto_data.length }
  string :auth_proto_name, read_length: :auth_proto_name_len
  skip length: lambda { (4 - (auth_proto_name_len % 4)) % 4 }
  string :auth_proto_data, read_length: :auth_proto_data_len
  skip length: lambda { (4 - (auth_proto_data_len % 4)) % 4 }
  skip length: 2 #???
end

class X11StdReqBody < BinData::Record
  endian :little
  uint16 :req_len
  string :data, read_length: lambda {(req_len - 1) * 4}
end

class X11ExtReqBody < BinData::Record
  rest :data
end

class X11StdReq < BinData::Record
  endian :little
  uint8 :opcode
  uint8 :subcode
  choice :req_type, selection: lambda { opcode <= 128 } do
    x11_std_req_body true
    x11_ext_req_body false
  end
end

class X11Req < BinData::Record
  choice :msg2, display_as: 'anon', selection: lambda { current_state[:connected] } do
    x11_setup_req false
    x11_std_req true
  end
end

class X11SetupRes < BinData::Record
  endian :little #more cheating
  uint8 :status
  skip length: 1
  uint16 :proto_major
  uint16 :proto_minor
  uint16 :addl_data_dwords
  uint32 :release_num
  uint32 :res_id_base, display_as: 'hex'
  uint32 :res_id_mask, display_as: 'hex'
  uint32 :motion_buffer_size
  uint16 :vendor_len, value: lambda { vendor.length }
  uint16 :max_req_len
  uint8  :num_screens
  uint8  :num_formats
  uint8  :image_byte_order
  uint8  :bitmap_bit_order
  uint8  :bitmap_format_scanline_unit
  uint8  :bitmap_format_scanlin_pad
  uint8  :min_keycode
  uint8  :max_keycode
  skip   length: 4
  string :vendor, read_length: :vendor_len
  string :vpad, read_length: lambda { (4 - ( vendor.length % 4 )) % 4 }
  rest   :listofformatandroots, display_as: 'hexdump'
end

class X11Reply < BinData::Record
  endian :little
  uint8 :detail
  uint16 :seq_num
  uint32 :extra_len
  string :data, length: lambda { 24 + (4 * extra_len) }, display_as: 'hexdump'
end

class X11Event < BinData::Record
  endian :little
  uint8 :detail
  string :data, length: 30, display_as: 'hexdump'
end

class X11Error < BinData::Record
  endian :little
  uint8 :detail
  string :data, length: 30, display_as: 'hexdump'
end

class X11StdRes < BinData::Record
  endian :little
  uint8 :res_type
  choice :res_detail, selection: :res_type do
    x11_error 0
    x11_reply 1
    x11_event :default
  end
end


class X11Res < BinData::Record
  choice :msg2, display_as: 'anon', selection: lambda { current_state[:connected] } do
    x11_setup_res false
    x11_std_res true
  end
end

class X11Proto < BinData::Record
  def self.initial_state; { connected: false, endian: nil }; end

  #XXX wrap this in something that dups the current state so we're unable to mutate it by accident
  def update_state
    c = current_state.dup
    if eval_parameter(:src) == 'server' #hack, assume we're connected after 1st c-s-c exchange
      c[:connected] = true
    end
    c
  end

  def summary
    msg.msg2.summary
  end

  choice :msg, selection: :src, display_as: 'anon' do
    x11_req 'client'
    x11_res 'server'
  end
end

