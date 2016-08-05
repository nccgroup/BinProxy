require 'rbkb'
require 'bindata'
require_relative 'bindata'
require_relative 'logger'
require_relative 'proxy_event'
require 'base64'

######################################################################
# monkey patch bindata classes to add annotated_snapshot
#
# Annotated snapshots should be hashes which convert cleanly to JSON and
# have the following properties:  (Note that this is somewhat different
# from the format of builtin BinData snapshots.)
#
#   name: string or null
#   objclass: string
#   display: string or null
#
#   [either]
#     contents: array of annotated_snapshots
#   [or]
#     value: primitive type
#     repr: 'raw' or 'base64'
#
######################################################################

class BinData::Base
  # Not called directly, but return value is merged by subclasses
  def annotated_snapshot
    {
      name: nil, #things generally don't know their own name, so compound types will overwrite this.
      objclass: self.class.to_s,
      display: eval_parameter(:display_as)
    }
  end
  def annotate_value(v)
    if v.respond_to? :annotated_snapshot
      return v.annotated_snapshot
    end
    v = Base64.encode64(v) if v.is_a? String
    return { value: v }
  end
end

class BinData::BasePrimitive
  def annotated_snapshot
    super.merge annotate_value(snapshot)
  end
end

#XXX should we pass along which choice, include what the options were?
class BinData::Choice
  def annotated_snapshot
    super.merge contents: [ current_choice.annotated_snapshot ], contents_type: :hash
  end
end

class BinData::Array
  def annotated_snapshot
    super.merge contents: elements.map { |el| el.annotated_snapshot }, contents_type: :array
  end
end

class BinData::Struct
  def annotated_snapshot
    super.merge( contents: field_names.map do |name|
      o = find_obj_for_name(name)
      o.annotated_snapshot.merge name: name if include_obj?(o)
    end.find_all { |x| x }, contents_type: :hash )
  end
end

class BinData::Primitive
  def annotated_snapshot
    super.merge annotate_value(snapshot)
  end
end

module BinProxy
  # This class represents a message being proxied, including the
  # raw bits, the BinData parsed representation, and metadata such
  # as the asssociated session, which direction it's going, and whether
  # it's been forwarded. [some of the above still TODO!]
  class ProxyMessage < BinProxy::ProxyBaseItem
    attr_accessor :message, :message_class, :force_reserialize
    attr_reader :modified


    def initialize(raw_bytes, parsed_message)
      super()
      @raw = raw_bytes
      @message = parsed_message
      @message_class = @message.class
      @modified = false
      @force_reserialize # XXX ???

      if @raw != @message.to_binary_s
        log.warn "WARNING, inconsistent binary representation:\n[[ORIGINAL]]\n#{@raw.hexdump}\n[[RESERIALIZED]]\n#{@message.to_binary_s.hexdump}"
        log.warn "... @raw encoding is #{@raw.encoding}; to_binary_s is #{@message.to_binary_s.encoding}"
      end
    end

    # The next two methods are the last stop before JSON encoding, so all strings
    # in the returned hash must be UTF-8 compatible.

    def headers
      super.merge({
        size: @raw.length,
        # HACK - this will prevent errors, but will mangle anything that isn't
        # actually utf8. We should try to handle this upstream where we might
        # know what the actual encoding is.
        summary: @message.summary.force_encoding('UTF-8').scrub,
        message_class: @message_class.to_s,
      })
    end

    def to_hash
      {
        head: headers,
        body: {
          snapshot: @message.annotated_snapshot,
          raw: Base64.encode64(@raw)
        }
      }
    end

    def to_binary_s
      if @modified or @force_reserialize
        @message.to_binary_s
      else
        @raw
      end
    end

    def update!(snapshot)
      @modified = true
      @message.assign( deannotate_snapshot(snapshot) )
    end

    def forward!(reason)
      @session.send_message(self)
      self.disposition = "Sent #{reason}"
    end

    def drop!(reason)
      self.disposition = "Dropped #{reason}"
    end

    def inspect #standard inspect pulls in junk from sesssion
      "#<#{self.class.to_s} #{self.to_hash}>"
    end

    private
    #turns the output of #annotated_snapshot into the format used by
    # #snapshot and #assign  XXX not fully tested w/ compound elements, esp arrays
    def deannotate_snapshot(s, out=nil)
      val = if s.has_key? :value
        if s[:value].is_a? String
          Base64.decode64(s[:value])
        else
          s[:value]
        end
      elsif s.has_key? :contents
        if s[:contents_type].to_s == 'hash'
          s[:contents].reduce({}) {|h, c| deannotate_snapshot(c, h) }
        elsif s[:contents_type].to_s == 'array'
          s[:contents].reduce([]) {|a, c| deannotate_snapshot(c, a) }
        else
          raise "Expected hash or array for contents_type, got #{s[:contents_type]}"
        end
      else
        raise "Snapshot has neither :value nor :contents key"
      end

      if out.nil? # top level item
        val
      elsif out.is_a? Hash
        raise "Expected :name for snapshot item within a hash" unless s.has_key? :name
        out[s[:name].to_sym] = val
        out
      elsif out.is_a? Array
        out << val
      else
        raise "Ooops!  out param s/b hash or array, but it was #{out.class}"
      end
    end



  end
end
