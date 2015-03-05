class Time
  def _to_fm
    d = strftime('%m/%d/%Y') #unless Date.today == Date.parse(self.to_s)
    t = strftime('%T')
    d ? "#{d} #{t}" : t
  end
end # Time

class DateTime
  def _to_fm
    d = strftime('%m/%d/%Y')
    t =strftime('%T')
    "#{d} #{t}"
  end
end # Time

class Timestamp
  def _to_fm
    d = strftime('%m/%d/%Y')
    t =strftime('%T')
    "#{d} #{t}"
  end
end # Time

class Date
  def _to_fm
    strftime('%m/%d/%Y')
  end
end # Time


module DataMapper
  [Adapters, Model, Query, Resource]
  
  # All this to tack on class and instance methods to the model/resource.
  module Resource
    class << self
      alias_method :included_orig, :included
      def included(klass)
        included_orig(klass)
        if klass.repository.adapter.to_s[/filemaker/i]
          klass.instance_eval do
            extend repository.adapter.class::ModelMethods
            include repository.adapter.class::ResourceMethods
          end
        end
      end
    end
  end
  
  module Model
    attr_accessor :last_query
    alias_method :finalize_orig, :finalize
    def finalize(*args)
      property :record_id, Integer, :lazy=>false
      property :mod_id, Integer, :lazy=>false
      finalize_orig
    end
  end
  
  class Query
		# Convert dm query conditions to fmp query params (hash)
	  def to_fmp_query(input=self.conditions)
	    #puts "FMP_QUERY input #{input.class.name}"
	    rslt = if input.class.name[/OrOperation/]
	    	#puts "FMP_QUERY OrOperation #{input.class}"
	      input.operands.collect do |o|
	      	r = to_fmp_query o
	      	#puts "FMP_QUERY or-operation operand #{r}"
	      	r
	      end
	    elsif input.class.name[/AndOperation/]
	    	#puts "FMP_QUERY AndOperation input class #{input.class}"
	    	#puts "FMP_QUERY AndOperation input value #{input.inspect}"
	    	out = {}
	      input.operands.each do |k,v|
	      	#puts "FMP_QUERY and-operation pre-process operand key:val #{k}:#{v}"
	        r = to_fmp_query(k).to_hash
	        #puts "FMP_QUERY and-operation post-process operand #{r}"
	        if r.is_a?(Hash)
	        	#puts "FMP_QUERY and-operation operand is a hash"
	        	# Filemaker can't have the same field twice in a single find request,
	        	# but we can mash the two conditions together in a way that FMP can use.
	          out.merge!(r){|k, oldv, newv| "#{oldv} #{newv}"}
	        else
	        	#puts "FMP_QUERY and-operation operand is NOT a hash"
	          out = r
	          break
	        end
	      end
	      out
	    elsif input.class.name[/NullOperation/] || input.nil?
	      #puts "FMP_QUERY NullOperation #{input.class}"
	      {}
	    else
	      #puts "FMP_QUERY else input class #{input.class}"
	      #puts "FMP_QUERY else input value #{input.inspect}"
	      #puts "FMP_QUERY else-options #{self.options.inspect}"
	      #prepare_fmp_attributes({input.subject=>input.value}, :prepend=>fmp_operator(input.class.name))
	      value = (
	      	self.options[input.keys[0]] ||
	      	self.options[input.subject.name] ||
	      	self.options.find{|o,v| o.respond_to?(:target) && o.target.to_s == input.subject.name.to_s}[1] ||
	      	input.value
	      ) rescue input.value   #(puts "ERROR #{$!}"; input.value)
	      #puts "FMP_QUERY else-value #{value}"
	      repository.adapter.prepare_fmp_attributes({input.subject=>value}, :prepend=>fmp_operator(input.class.name))
	    end
	    #puts "FMP_QUERY output #{rslt.inspect}"
	    rslt
	  end # to_fmp_query
	  
		# Convert operation class to operator string
		def fmp_operator(operation)
		  case
		  when operation[/GreaterThanOrEqualTo/]; '>='
		  when operation[/LessThanOrEqualTo/]; '<='
		  when operation[/GreaterThan/]; '>'
		  when operation[/LessThan/]; '<'
		  when operation[/EqualTo/]; '=='
		  when operation[/Like/];
		  when operation[/Null/];
		  else nil
		  end
		end

    # Get fmp options hash from query
    def fmp_options(query=self)
      fm_options = {}
      fm_options[:skip_records] = query.offset if query.offset
      fm_options[:max_records] = query.limit if query.limit
      if query.order
        fm_options[:sort_field] = query.order.collect do |ord|
          ord.target.field
        end
        fm_options[:sort_order] = query.order.collect do |ord|
          ord.operator.to_s + 'end'
        end
      end
      fm_options
    end	  
    
  end # Query
end # DataMapper