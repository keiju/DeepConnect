
require "thread"
require "e2mmap"

module DeepConnect

  class ClassSpecSpace
    NULL = :NULL

    def initialize(remote = :remote)
      case remote
      when :remote
	@class_specs = nil
      when :local
	@class_specs = {}
      end

      @class_specs_mutex = Mutex.new
      @class_specs_cv = ConditionVariable.new

      @method_spec_cache = {}
    end

    def class_spec_id_of(obj)
      ancestors = obj.class.ancestors
      begin
	single = (class<<obj;self;end)
	ancestors.unshift single
      rescue
      end
#p ancestors
#      p ancestors.collect{|e| e.object_id}
      klass = ancestors.find{|kls|
	@class_specs[kls.object_id]
      }
      if klass
	klass.object_id
      else
	nil
      end
    end

    def method_spec(ref_or_obj, method)
      puts "method_spec(#{ref_or_obj}, #{method})" if DISPLAY_METHOD_SPEC
      if ref_or_obj.__deep_connect_reference?
	csid = ref_or_obj.csid
      else
	csid = class_spec_id_of(ref_or_obj)
      end
      return nil unless csid

#      mid = [csid, method]
#      mid = sprintf("%X-%s", csid, method)
      mid = "#{csid}-#{method}"
      case mspec = @method_spec_cache[mid]
      when nil
	# pass
      when NULL
	return nil
      else
	return mspec
      end

      class_spec_ancestors(csid) do |cspec|
	if mspec = cspec.method_spec(method)
	  return mspec
	end
      end
      @method_spec_cache[mid] = NULL
      return nil
    end

    def def_method_spec(klass, *method_spec)
      csid = klass.object_id
      unless cspec = @class_specs[csid]
	cspec = ClassSpec.new(klass)
	@class_specs[csid] = cspec
      end
      
      if method_spec.size == 1 and method_spec.first.kind_of?(MethodSpec)
	mspec = method_spec.first
      else
	mspec = MethodSpec.spec(*method_spec)
      end
      cspec.add_method_spec(mspec)
    end

    def def_single_method_spec(obj, method_spec)
      klass = class<<obj;self;end
      def_method_spec(klass, method_spec)
    end

    def def_interface(klass, method)
      mspec = MethodSpec.new
      mspec.method = method
      mspec.interface = true
      def_method_spec(klass, mspec)
    end

    def def_single_interface(obj, method)
      klass = class<<obj;self;end
      def_interface(klass, method)
    end

    def class_specs=(cspecs)
      @class_specs_mutex.synchronize do
	@class_specs = cspecs
	@class_specs_cv.broadcast
      end
    end

    def class_specs
      @class_specs_mutex.synchronize do
	while !@class_specs
	  @class_specs_cv.wait(@class_specs_mutex)
	end
	@class_specs
      end
    end

    def class_spec_ancestors(csid, &block)
      @class_specs_mutex.synchronize do
	while !@class_specs
	  @class_specs_cv.wait(@class_specs_mutex)
	end
      end

      class_spec = @class_specs[csid]
      
      class_spec.ancestors.select{|anc| @class_specs[anc]}.each{|anc|
	yield @class_specs[anc]
      }
    end

  end

  class ClassSpec
    def initialize(klass)
      @name = klass.name
      @csid = klass.object_id
      ancestors = klass.ancestors
      ancestors.unshift klass
      @ancestors = ancestors.collect{|k| k.object_id}
      @method_specs = {}
    end

    attr_reader :name
    attr_reader :csid
    attr_reader :ancestors

    def add_method_spec(mspec)
      if sp = @method_specs[mspec.method]
	@method_specs[mspec.method].override(mspec)
      else
	@method_specs[mspec.method] = mspec
      end
    end

    def method_spec(method)
      @method_specs[method]
    end

  end

  class MethodSpec
    extend Exception2MessageMapper

    def_exception :UnrecognizedError, "パーズできません(%s)"

    # method(arg_spec, ..., *arg_spec)
    # ret_spec, ... method()
    # ret_spec, ... method(arg_spec, ..., *arg_spec)
    # ret_spec, ... method() block_ret, ... {}
    # ret_spec, ... method() {arg_spec, ...}
    # ret_spec, ... method() block_ret, ... {arg_spec, ...}
    # ret_spec, ... method(arg_spec, ..., *arg_spec) block_ret, ...  {arg_spec, ...}

    # *****method が記号の時できてない

    ARG_SPEC = ["DEFAULT", "REF", "VAL", "DVAL"]
    # VALができるのは, Array, Hash のみ, Structは相手にも同一クラスがあれば可能

    def self.spec(spec)
      mspec = MethodSpec.new
      case spec
      when String
	mspec.parse(spec)
      when Hash
	mspec.direct_setting(spec)
      else
	raise "スペック指定は文字列もしくはキーワード指定です"
      end
      mspec
    end

    def initialize
      @rets = nil
      @method = nil
      @args = nil
      @block_rets = nil
      @block_args = nil

      @interface = nil
    end

    attr_accessor :rets
    attr_accessor :method
    attr_accessor :args
    attr_accessor :block_rets
    attr_accessor :block_args
    attr_accessor :interface
    alias interface? interface

    def has_block? 
      @block_rets || @block_args 
    end

    def override(mspec)
      if mspec.rets
	@rets = mspec.rets
      end
      if mspec.args
	@args = mspec.args
      end
      if mspec.block_rets
	@block_rets = mspec.block.rets
      end
      if mspec.block_args
	@block_args = mspec.block_args
      end
      if mspec.interface
	@interface = mspec.interface
      end
    end

    class ArgSpecs
      include Enumerable
      def initialize(arg_specs)
	@arg_specs = arg_specs.dup
      end

      def each
	while arg_spec = @arg_specs.shift
	  if arg_spec.mult?
	    @arg_specs.unshift arg_spec
	  end
	  yield arg_spec
	end
      end

      def succ
	if (ret = @arg_specs.shift) && ret.mult?
	  @arg_specs.unshift ret
	end
	ret
      end

    end

    def rets_zip(rets, &block)
      retspecs = ArgSpecs.new(@rets)
      begin
	param_zip(retspecs, rets, &block)
      rescue ArgumentError
	raise ArgumentError,
	  "argument spec mismatch rets: #{@rets}"
      end
    end

    def arg_zip(args, &block)
      argspecs = ArgSpecs.new(@args)
      begin
	param_zip(argspecs, args, &block)
      rescue ArgumentError
	raise ArgumentError,
	  "argument spec mismatch args: #{@args}"
      end
    end

    def block_arg_zip(args, &block)
      argspecs = ArgSpecs.new(@block_args)
      begin
	param_zip(argspecs, args, &block)
      rescue ArgumentError
	raise ArgumentError,
	  "argument spec mismatch block args: #{@block_args}"
      end
    end

    def param_zip(arg_specs, args, &block)
      ary = []
      args.each do |arg|
	spec = arg_specs.succ
	unless spec
	  raise ArgumentError
	end
	ary.push yield(spec, arg)
      end
      ary
    end

    def to_s
      spec = ""
      case @rets
      when nil
      when Array
	spec.concat(@rets.join(", "))
	spec.concat(" ")
      when
	spec.concat(@rets.to_s)
	spec.concat(" ")
      end
      
      if @method
	spec.concat(@method.to_s)
      else
	spec.concat("(missing)")
      end
      if @args
	spec.concat("("+@args.join(", ")+")")
      end
      if has_block?
	if @block_rets
	  spec.concat(@block_rets.join(", "))
	end
	if @block_args
	  spec.concat("{"+@block_args.join(", ")+"}")
	else
	  spec.concat("{}")
	end
      end
      "#<#{self.class} #{spec} >"
    end

    class ParamSpec
      def self.identifier(token, *opts)
	case token
	when String
	  name = token
	  if /^\*(.*)/ =~ token
	    name = $1
	    opts.push :mult
	  end
	when Token
	  name = token.name
	end

	klass = Name2ParamSpec[name]
	unless klass
	  MethodSpec.Raise UnrecognizedError, name
	end
	pspec = klass.new(name)
	if opts.include?(:mult)
	  pspec.mult = true
	end
	pspec
      end

      def self.param_specs(string_ary)
	case string_ary
	when nil
	  nil
	when Array
	  string_ary.collect{|e| ParamSpec.identifier(e)}
	else
	  [ParamSpec.identifier(string_ary)]
	end
      end

      def initialize(name)
	@type = name

	@mult = nil
      end

      attr_reader :type
      attr_accessor :mult
      alias mult? mult

      def to_s
	if mult
	  "*"+@type
	else
	  @type
	end
      end
    end
    
    class DefaultParamSpec<ParamSpec;end
    class RefParamSpec<ParamSpec;end
    class ValParamSpec<ParamSpec;end
    class DValParamSpec<ParamSpec;end
    
    Name2ParamSpec = {
      "DEFAULT"=>DefaultParamSpec,
      "REF" => RefParamSpec,
      "VAL" => ValParamSpec,
      "DVAL" => DValParamSpec
    }

    def direct_setting(opts)
      if opts[:rets]
	@rets = ParamSpec.param_specs(opts[:rets])
	if @rets.size == 1
	  @rets = @rets.first
	end
      end

      @method = opts[:method]
      @method = @method.intern unless @method.kind_of?(Symbol)

      if opts[:args]
	@args = ParamSpec.param_specs(opts[:args])
      end

      if opts[:block_rets]
	@block_rets = ParamSpec.param_specs(opts[:block_rets])
	if @block_rets.size == 1
	  @block_rets = @block_rets.first
	end
      end
      if opts[:block_args]
	@block_args = ParamSpec.param_specs(opts[:block_args])
      end
    end

    # private method
    def parse(spec)
      tokener = Tokener.new(spec)
      
      tk1, tk2 = tokener.next, tokener.peek
      tokener.unget tk1
      case tk1
      when TkIdentifier
	case tk2
	when nil
	when TkIdentifier, TkCOMMA, TkMULT
	  parse_rets(tokener, spec)
	when TkLPAREN, TkLBRACE
	else
	  MethodSpec.Raise UnrecognizedError, spec
	end
      when TkMULTI
	parse_rets(tokener, spec)
      else
	MethodSpec.Raise UnrecognizedError, spec
      end
      
      parse_method(tokener, spec)
      parse_args(tokener, spec)
      parse_block(tokener, spec)
    end

    def parse_rets(tokener, spec)
      @rets = parse_params(tokener, spec)
      if @rets && @rets.size == 1
	@rets = @rets.first
      end
    end

    def parse_method(tokener, spec)
      tk = tokener.next
      case tk
      when TkIdentifier
	@method = tk.name.intern
      else
	MethodSpec.Raise UnrecognizedError, tk.to_s+ " in " +spec
      end
    end

    def parse_args(tokener, spec)
      tk = tokener.next
      case tk
      when TkLPAREN
	@args = parse_params(tokener, spec)
	tk2 = tokener.next
	unless tk2 == TkRPAREN
	  MethodSpec.Raise UnrecognizedError, tk2 + " in " +spec
	end
      else
	# パラメータなし
      end
    end

    def parse_block(tokener, spec)
      parse_block_rets(tokener, spec)
      tk = tokener.peek
      unless tk == TkLBRACE
	if @block_rets
	  MethodSpec.Raise UnrecognizedError, "ブロック定義では`{'が必要です(#{tk.to_s}, #{spec})"
	else
	  return
	end
      end
      parse_block_args(tokener, spec)
    end

    def parse_block_rets(tokner, spec)
      @block_rets = parse_params(tokner, spec)
      if @block_rets
	if @block_rets && @block_rets.size == 1
	  @block_rets = @block_rets.first
	end
      end
    end

    def parse_block_args(tokener, spec)
      tk = tokener.next
      case tk
      when TkLBRACE
	@block_args = parse_params(tokener, spec)
	@args = parse_params(tokener, spec)
	tk2 = tokener.next
	unless tk2 == TkRBRACE
	  MethodSpec.Raise UnrecognizedError, tk2 +" in " +spec
	end
      else
	# パラメータなし
      end
    end

    def parse_params(tokener, spec)
      args = []
      while token = tokener.next
	case token
	when TkIdentifier
	  case tk2 = tokener.peek
	  when nil
	    args.push ArgSpec.identifier(token)
	    break
	  when TkMULT
	    MethodSpec.Raise UnrecognizedError, token
	  when TkCOMMA
	    tokener.next
	    args.push ParamSpec.identifier(token)
	  when TkIdentifier, TkRPAREN, TkRBRACE
	    args.push  ParamSpec.identifier(token)
	    break
	  when TkLPAREN, TkLBRACE
	    args.push ParamSpec.identifier(token)
	    break
	  else
	    MethodSpec.Raise UnrecognizedError, "不正な文字#{tk2}が入っています"
	  end
	when TkMULT
	  case token2 = tokener.next
	  when nil
	    MethodSpec.Raise UnrecognizedError, "*で終わっています"
	  when TkIdentifier
	    args.push  ParamSpec.identifier(token2, :mult)
	    break
	  else
	    MethodSpec.Raise UnrecognizedError, "*の後に#{token2}が入っています"
	  end
	else # TkRPAREN, TkRBRACE
	  tokener.unget token
	  break
	end
      end
      if args.empty?
	nil
      else
	args
      end
    end

    class Token; end
    class TkIdentifier<Token
      def initialize(name)
	@name = name
      end
      attr_reader :name

      def to_s
	"#<#{self.class} #{@name}>"
      end
    end

    TkMULT = "*"
    TkLPAREN = "("
    TkLBRACE = "{"
    TkRPAREN = ")"
    TkRBRACE = "}"
    TkCOMMA = ","

    class Tokener
      def initialize(src)
	@src = src.split(//)
	@tokens = []
      end

      def next
	return @tokens.shift unless @tokens.empty?

	while /\s/ =~ @src[0]; @src.shift; end

	case @src[0]
	when nil
	  nil
	when ",", "(", ")", "{", "}", "*"
	  reading = @src.shift
	when /\w/
	  identify_identifier
	else
	  MethodSpec.Raise UnrecognizedError, @src.join("")
	end
      end

      def peek
	@tokens.first unless @tokens.empty?

	token = self.next
	@tokens.push(token) if token
	token
      end

      def unget(token)
	@tokens.unshift token
      end

      def identify_identifier
	toks = []
	while s = @src.shift
	  if /[\w]/ =~ s
	    toks.push s
	  else
	    @src.unshift s
	    break
	  end
	end
	reading = toks.join("")
	TkIdentifier.new(reading)
      end
    end

    def self.mkkey(receiver, method_name)
      if receiver.__deep_connect_reference?
	receiver.class.name+"#"+method_name.to_s
      elsif receiver.kind_of?(Class)
	receiver.name+"."+method_name.to_s
      else
	receiver.class.name+"#"+method_name.to_s
      end
    end
  end
end
