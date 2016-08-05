
class ChatDemo < BinData::Record
  endian  :little
  uint32  :timestamp
  string  :user, length: 8, trim_padding: true
  bit1    :emote_flag
  bit1    :private_flag
  string  :recipient, length: 8, trim_padding: true, onlyif: :private_flag
  stringz :message

  def summary
    "#{emote_flag ? 'emote' : 'message'} from #{user}"
  end
end
