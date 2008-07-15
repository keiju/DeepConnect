#
#   serialize.rb - 
#   	$Release Version: $
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Penta Advanced Labrabries, Co.,Ltd)
#
# --
#
#   
#

require "deep-connect/reference"

module DeepConnect
  UNSERIALIZABLE_CLASSES = [
    StopIteration,
    Enumerable::Enumerator,
    Binding,
    UnboundMethod,
    Method,
    Proc,
    Dir,
    File,
    IO,
    ThreadGroup,
    Continuation,
    Thread,
    Data,
    Class,
    Module,
  ]
  UNSERIALIZABLE_CLASS_SET = {}
  UNSERIALIZABLE_CLASSES.each do|k|
    UNSERIALIZABLE_CLASS_SET[k] = k
  end
end

class Object 
  def deep_connect_serialize_val(deep_space)
    if DeepConnect::UNSERIALIZABLE_CLASS_SET.include?(self.class)
      raise "#{self.class}はシリアライズできません"
    end
    vnames = instance_variables
    vnames.collect{|v| [v, instance_variable_get(v)]}
  end

  def self.deep_connect_materialize_val(deep_space, value)
    obj = allocate
    value.each do |v, o|
      obj.instance_variable_set(v, o)
    end
    obj
  end
end

class Array
  def deep_connect_serialize_val(deep_space)
    collect{|e| DeepConnect::Reference.serialize(deep_space, e)}
  end

  def self.deep_connect_materialize_val(deep_space, value)
    ary = new
    value.each{|e| ary.push DeepConnect::Reference.materialize(deep_space, *e)}
    ary
  end

end

class Hash
  def deep_connect_serialize_val(deep_space)
    collect{|k, v| 
      [DeepConnect::Reference.serialize(deep_space, k), 
	DeepConnect::Reference.serialize(deep_space, v)]}
  end

  def self.deep_connect_materialize_val(deep_space, value)
    hash = new
    value.each do |k, v| 
      key = DeepConnect::Reference.materialize(deep_space, *k)
      value = DeepConnect::Reference.materialize(deep_space, *v)
      hash[key] = value
    end
    hash
  end

end

class Struct
  def deep_connect_serialize_val(deep_space)
    to_a.collect{|e| DeepConnect::Reference.serialize(deep_space, e)}
  end

  def self.deep_connect_materialize_val(deep_space, value)
    new(*value.collect{|e| DeepConnect::Reference.materialize(deep_space, *e)})
  end
end


