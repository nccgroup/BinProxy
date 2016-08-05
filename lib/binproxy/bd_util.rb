require 'bindata'

=begin
 class BinData::Base
   def real_inspect
     "#<#{self.class}:#{self.object_id} #{self.instance_variables.map do |v|
       "#{v}=#{
         tmp = self.instance_variable_get v
         if tmp.respond_to? :real_inspect
           tmp.real_inspect
         else
           tmp.inspect
         end
       }"
     end.join ' '}>"
   end
 end
=end

class BinData::Line < BinData::BasePrimitive
  default_parameter line_end: "\n"

  def sensible_default; ""; end

  #XXX not sure if this does the right thing wrt non-ascii input
  # can you slip CR or LF in via other encodings?
  def value_to_binary_string(v)
    v.to_s.chomp.dup.force_encoding('BINARY').chomp + eval_parameter(:line_end)
  end

  def read_and_return_value(io)
    ch = nil
    str = ''
    loop do
      ch = io.readbytes(1)
      if ch == "\n"
        break
      elsif ch == "\r"
        ch = io.readbytes(1)
        io.raw_io.ungetbyte(ch) unless ch == "\n"
        break
      end
      str << ch
    end
    str
  end
end

module BinData
  class ArgProcessorWrapper
    def initialize(original_processor, &blk)
      @original = original_processor
      @block = blk
    end

    def sanitize_parameters!(obj_class, obj_params)
      @original.sanitize_parameters!(obj_class, obj_params)
      @block.call(obj_class, obj_params)
    end

    def method_missing(sym, *args)
      @original.send(sym, *args)
    end
  end      

  module ClassParametersPlugin
    module ClassMethods
      def class_parameter(sym)
        ( @class_params ||= [] ) << sym
      end
      
    end
    def self.included(obj_class)
      # Wrap the obj_class's existing arg_processor
      old_arg_processor = obj_class.arg_processor
      new_arg_processor = ArgProcessorWrapper.new(old_arg_processor) do |obj_class,params|
        class_params = obj_class.class_eval {@class_params} || []
        class_params.each do |type|
          if params.needs_sanitizing?(type)
            t,p = params[type]
            params[type] = params.create_sanitized_object_prototype(t,p)
          end
        end
      end
      obj_class.class_eval do 
        @arg_processor = new_arg_processor
      end

      # add class_parameter(:foo) to our class methods / DSL
      obj_class.extend ClassMethods
    end


  end
end

=begin
I'm not sure there's a good way to make this work without a LOT of hackery...

# This class basically exists so we can have type params in DSL-based classes.
# See PascalString for an example
class BinData::Variant < BinData::BasePrimitive
  extend HasClassParameters
  mandatory_parameter :type
  class_parameter :type

  def initialize_instance
    @obj = get_parameter(:type).instantiate(nil,self)
    @default = @obj.snapshot #should test if reference types need dup here TODO
  end

  def value_to_binary_string(v)
    @obj.assign(v)
    @obj.to_binary_s
  end

  def read_and_return_value(io)
    @obj.read(io)
    @obj.snapshot
  end

  def sensible_default
    @default
  end
end

=end

# Like the Pascal String class shown in the docs, but with a variable type of
# length specifier.
class BinData::PascalString < BinData::BasePrimitive
  include ::BinData::ClassParametersPlugin
  default_parameter size_type: :uint8
  class_parameter :size_type

  def initialize_instance
    @len_obj = get_parameter(:size_type).instantiate(nil,self)
  end

  # override this instead of using value_to_binary_string, so that
  # we don't have to start out byte aligned (the string portion
  # will still be aligned, though).
  def do_write(io)
    @len_obj.assign(_value.bytes.count)
    @len_obj.write(io)
    io.writebytes(_value)
  end

  # again, override for proper bit handling
  def do_num_bytes
    @len_obj.num_bytes + _value.bytes.count
  end

  # only called by do_write and do_num_bytes, which we've overridden, so
  # shouldn't ever be called.
  def value_to_binary_string(v)
    raise RuntimeError.new "this should never be called"
  end

  def read_and_return_value(io)
    @len_obj.read(io)
    s = BinData::String.new(read_length: @len_obj).read(io)
    s.snapshot
  end

  def sensible_default
    ""
  end
end

class BinData::Peek < BinData::BasePrimitive
  include BinData::ClassParametersPlugin
  default_parameter type: :uint8
  class_parameter :type

  def initialize_instance
    @proto = get_parameter :type
  end

  def value_to_binary_string(val)
    ''
  end

  def read_and_return_value(io)
    #TODO - make this work rather than punting on it
    if io.instance_eval {@rnbits} > 0
      raise "cannot peek when not byte aligned!"
    end

    obj = get_parameter(:type).instantiate(nil,self)


    io = io.raw_io
    pos = io.pos
    begin
      obj.read(io)
    ensure
      io.pos = pos
    end

    obj
  end

  def sensible_default
    0
  end
end

#Need this for positioning underlying IO, which
#we use to avoid altering BD::IO state (i.e. bits read)
#TODO find a less hacky way to do all this
module BinData::IO::Read::SeekableStream
  attr_reader :initial_pos
  public :raw_io
end

class BinData::Pointer < BinData::BasePrimitive
  include BinData::ClassParametersPlugin
  mandatory_parameter :ptr_type
  class_parameter :ptr_type

  #TODO - support seek from current pos?
  #default_parameter ptr_from: :start

  mandatory_parameter :val_type
  class_parameter :val_type

  default_parameter seek_from: :start #one of :start, :raw_start, or :current
  default_parameter seek_offset: 0 #TODO possibly what I want is to name a specific parent object to count from

  attr_reader :ptr, :val

  def read_and_return_value(io)
    ptr_obj = get_parameter(:ptr_type).instantiate(nil,self)
    val_obj = get_parameter(:val_type).instantiate(nil,self)
    ptr = ptr_obj.read(io)

    rio = io.raw_io
    pos = rio.pos

    base = case get_parameter(:seek_from)
        when :raw_start  then 0
        when :start      then io.initial_pos
        when :current    then pos + ptr
        else raise "Invalid seek_from parameter"
        end

    rio.seek base + get_parameter(:seek_offset) + ptr
    val_obj.read(rio)
    rio.seek pos

    #{p: ptr_obj, v: val_obj}
    val_obj
  end

  #XXX hacky below, handles reading only

  def value_to_binary_string(v)
    v.to_binary_s
  end

  def sensible_default
    #{p: 0, v: nil}
    get_parameter(:val_type).instantiate(nil,self)
  end

end
