require 'bindata'
#This file collects various monkey-patches

# Monkey-patch no-ops for state handling; user can override if needed.  Note:
# can't use nil as parameter value, so use empty string as placeholder.
class BinData::Base
  def self.initial_state; ''; end
  def current_state; eval_parameter(:protocol_state) || @parent && @parent.current_state ; end
  def update_state; current_state; end
  def summary
    "#{self.class}: #{num_bytes} bytes of data"
  end
end
class BinData::Choice
  def summary
    current_choice.summary
  end
end

=begin
class BinData::LazyEvaluator
  #This is similar to a simplified lazy_eval, but starts w/ @obj, not @obj.parent
  def lazy_eval_self(val)
    if val.is_a? Symbol
      @obj.send(val)
    elsif val.respond_to? :arity
      @obj.instance_exec(&val) #??
    else
      val
    end
  end
end

class BinData::DSLMixin::DSLParser
  def summary(arg=nil, &b)
    raise "expected one arg or block" unless arg.nil? ^ b.nil?
    @the_class.class_exec do
      define_method(:summary) do
        lazy_evaluator.lazy_eval_self(arg || b)
      end
    end
  end
end
=end
