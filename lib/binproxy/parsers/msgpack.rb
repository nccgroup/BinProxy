require 'bindata'

class MsgPack
  class MpNil < BinData::Primitive
    def get; nil; end
    def set(v); raise unless v.nil? end;
  end
  class MpTrue < BinData::Primitive
    def get; true; end
    def set(v); raise unless v; end
  end
  class MpFalse < BinData::Primitive
    def get; false; end
    def set(v); raise unless !v; end
  end
  class


  class TypedValue < BinData::Choice
    positive_fixint :positive_fixint
    fixmap :fixmap
    fixarray :fixarray
    fixstr :fixstr
    mp_nil :nil
    mp_true :true
    mp_false :false
    bin8 :bin8
  end

  uint8 :type_byte
  typed_value :value, selection: lambda do
    case type_byte
    when 0..0x7f
      :positive_fixint
    when 0x80..0x8f
      :fixmap
    when 0x90..0x9f
      :fixarray
    when 0xa0..0xbf
      :fixstr
    when 0xc0
      :nil
    when 0xc1
      :unused
    when 0xc2
      :true
    when 0xc3
      :false
    when 0xc4
      :bin8
    else
      raise 'todo'
    end
  end
  end
end
