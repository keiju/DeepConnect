
require "e2mmap"

module DeepConnect
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

    ARG_SPEC = ["DEFAULT", "REF", "VAL", "DVAL"]
    # VALができるのは, Array, Hash のみ, Structは相手にも同一クラスがあれば可能

    def self.create(klass, spec)
      mspec = MethodSpec.new
      if klass.kind_of?(String)
	mspec.klass = klass
      else
	mspec.klass = klass.name
      end
      mspec.parse(spec)
      mspec
    end

    def self.create_single(klass, spec)
      mspec = create(klass, spec)
      mspec.sinlgeton = true
      mspec
    end 

    def initialize
      @rets = nil
      @klass = nil
      @singleton = nil
      @method = nil
      @args = nil
      @block_rets = nil
      @block_args = nil
    end

    attr_accessor :rets
    attr_accessor :klass
    attr_accessor :obj
    attr_accessor :singleton
    attr_accessor :method
    attr_accessor :args
    attr_accessor :block_rets
    attr_accessor :block_args

    def has_block? 
      @block_rets || @block_args 
    end

    alias singleton? singleton

    def key
      @klass+(singleton? ? "." : "#")+@method
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
	ary.push yield spec, arg
      end
      ary
    end

    def to_s
      spec = ""
      if @rets
	spec.concat(@rets.join(", "))
	spec.concat(" ")
      end
      
      if @klass
	spec.concat(@klass)
      else
	spec.concat("(missing)")
      end
      if @singleton
	spec.concat(".")
      else
	spec.concat("#")
      end
      if @method
	spec.concat(@method)
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
	name = token.name
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
      if @rets.size == 1
	@rets = @rets.first
      end
      
    end

    def parse_method(tokener, spec)
      tk = tokener.next
      case tk
      when TkIdentifier
	@method = tk.name
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
      if @block_rets && @block_rets.size == 1
	@block_rets = @block_rets.first
      end
    end

    def parse_block_args(tokener, spec)
      tk = tokener.next
      case tk
      when TkLBRACE
	@block_args = parse_params(tokener, spec)
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
	    return args
	  when TkMULT
	    MethodSpec.Raise UnrecognizedError, token
	  when TkCOMMA
	    tokener.next
	    args.push ParamSpec.identifier(token)
	  when TkIdentifier, TkRPAREN, TkRBRACE
	    args.push  ParamSpec.identifier(token)
	    return args
	  when TkLPAREN, TkLBRACE
	    args.push ParamSpec.identifier(token)
	    return args
	  else
	    MethodSpec.Raise UnrecognizedError, "不正な文字#{tk2}が入っています"
	  end
	when TkMULT
	  case token2 = tokener.next
	  when nil
	    MethodSpec.Raise UnrecognizedError, "*で終わっています"
	  when TkIdentifier
	    args.push  ParamSpec.identifier(token2, :mult)
	    return args
	  else
	    MethodSpec.Raise UnrecognizedError, "*の後に#{token2}が入っています"
	  end
	else # TkRPAREN, TkRBRACE
	  tokener.unget token
	  return args
	end
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
      case receiver
      when Reference
	receiver.class_name+"#"+method_name.to_s
      when Class
	receiver.name+"."+method_name.to_s
      else
	receiver.class.name+"#"+method_name.to_s
      end
    end
  end
end
