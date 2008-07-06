
module DeepConnect
  class MethodSpec

    # ret_spec, ... method(arg_spec, ..., *arg_spec){|arg_spec, ...|}
    # ret_spec method(arg_spec, ..., *arg_spec){|arg_spec, ...|}
    # ret_spec method(arg_spec, ..., *arg_spec){|arg_spec, ...|}

    ARG_SPEC = /^(DEFAULT|REF|VAL|DVAL)$/
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
      @block_args = nil
    end

    attr_accessor :rets
    attr_accessor :klass
    attr_accessor :obj
    attr_accessor :singleton
    attr_accessor :method
    attr_accessor :args
    attr_accessor :block_args

    alias has_block? block_args
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
	  if /^\*(.*)$/ =~ arg_spec 
	    @arg_specs.unshift arg_spec
	    arg_spec = $1
	  end
	  yield arg_spec
	end
      end

      def succ
	case ret = @arg_specs.shift
	when /^\*(.*)$/
	  @arg_specs.unshift ret
	  $1
	else
	  ret
	end
      end

    end

    def rets_zip(rets, &block)
      retspecs = ArgSpecs.new(@rets)
      ary = []
      rets.each do |arg|
	spec = retspecs.succ
	unless spec
	  raise ArgumentError,
	    "argument spec mismatch argument: #{@args}"
	end
	ary.push yield spec, arg
      end
      ary
    end

    def arg_zip(args, &block)
      argspecs = ArgSpecs.new(@args)
      ary = []
      args.each do |arg|
	spec = argspecs.succ
	unless spec
	  raise ArgumentError,
	    "argument spec mismatch argument: #{@args}"
	end
	ary.push yield spec, arg
      end
      ary
    end

    def block_arg_zip(args, &block)
      argspecs = ArgSpecs.new(@block_args)

      ary = []
      args.each do |arg|
	spec = argspecs.succ
	unless spec
	  raise ArgumentError,
	    "argument spec mismatch argument: #{@args}"
	end
	ary.push yield spec, arg
      end
      ary
    end

    # private method
    def parse(spec)
      rets = []
      while spec.sub!(/^([\w]+)[,\s]\s*/, "")
	ret = $1
	unless ARG_SPEC =~ ret
	  raise ArgumentError, 
	    "returen is only specified #{ARG_SPEC.source}.(#{ret})" 
	end
	rets.push ret
      end
      if spec.sub!(/^(\*[\w)]+)[\s\($]\s*/, "")
	ret = $1
	unless ARG_SPEC =~ ret[1..-1]
	  raise ArgumentError, 
	    "*argument is only specified *#{ARG_SPEC.source}(#{ret})" 
	end
	rets.push ret
      end
      if rets.size == 1
	@rets = rets.first
      else
	@rets = rets
      end

      if spec.sub!(/^([^({$\s]+)/, "")
	@method = $1
      end
      
      if spec.sub!(/\(/, "")
      
	args = []
	while spec.sub!(/^([\w]+)[,\)$]\s*/, "")
	  arg = $1
	  unless ARG_SPEC =~ arg
	    raise ArgumentError, 
	      "argument is only specified #{ARG_SPEC.source}(#{arg})" 
	  end
	  args.push arg
	end
	if spec.sub!(/^(\*[\w]+)[,\)$]\s*/, "")
	  arg = $1
	  unless ARG_SPEC =~ arg[1..-1]
	    raise ArgumentError, 
	      "*argument is only specified *#{ARG_SPEC.source}(#{arg})" 
	  end
	  args.push arg
	end
	@args = args
      end

      if spec.sub!(/^\{\s*\|\s*/, "")
	block_args = []
	while  spec.sub!(/^([^,\|]+)[,\|]\s*/, "")
	  arg = $1
	  unless ARG_SPEC =~ arg
	    raise ArgumentError, 
	      "block argument is only specified #{ARG_SPEC.source}(#{arg})" 
	  end
	  block_args.push arg
	end
	if spec.sub!(/^(\*[^,\|]+)[,\|]\s*/, "")
	  arg = $1
	  unless ARG_SPEC =~ arg[1,-1]
	    raise ArgumentError, 
	      "*argument is only specified *#{ARG_SPEC.source}(#{arg})" 
	  end
	  block_args.push arg
	end
	if /\|\s*\}\s*$/ =~ spec
	  raise ArgumentError, "block spec must be finish \"|}\"(#{spec})"
	end
	@block_args = block_args
      else
	unless /^\s*$/ =~ spec
	  raise ArgumentError, "unrecognized: #{spec.inspect}, #{self.inspect}"
	end
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
