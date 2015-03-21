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
  	# For testing adapter methods.
    attr_accessor :last_query
  end # Model
  
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

module Rfm

	# Monkey patch for Rfm <= v3.0.8. (Rfm v1 or v2 will not work for DM)
	if (Rfm::VERSION.major.to_i == 3 and Rfm::VERSION.minor.to_i < 1 and Rfm::VERSION.patch.to_i < 9)
		Rfm::Connection.class_eval do
			Rfm::SaxParser::TEMPLATE_PREFIX.replace ''
			alias_method :parse_original, :parse
			def parse(*args)
				args[0] = DataMapper::Adapters::FilemakerAdapter::FMRESULTSET_TEMPLATE[:template]
				parse_original(*args)
			end
		end
	end


	class Resultset
	  
	  # Does custom processing during each record-to-resource translation done in DataMapper::Model#load
	  # Doing this here means we don't have to mess with DataMapper::Model#load.
	  def map
	    super do |record|
	      resource = yield(record)
	      #puts "DM INPUT RECORD: #{record.class} #{record.instance_variable_get(:@record_id)}"

				if resource.kind_of?(DataMapper::Resource)
					#puts "MODEL#LOAD custom processing RECORD #{record.class} RESOURCE #{resource.class}"
					#puts record.inspect
	        # For Testing:
	        resource.instance_variable_set(:@record, record)
	        # WBR - Loads portal data into DM model attached to this resource.
	        portals = record.instance_variable_get(:@portals)
	        #puts "MODEL#LOAD record: #{record.class} portals: #{portals.keys rescue 'no portals'}"
	        #if record.respond_to?(:portals) && record.portals.kind_of?(Hash) && record.portals.any?
	        model = resource.class
	        return unless model.kind_of?(DataMapper::Model)
	        #puts "MODEL#LOAD resource class: #{model}"
	        if portals.kind_of?(Hash) && portals.any?
	          begin
		          #puts record.portals.to_yaml
		          portal_keys = portals.keys
		          #puts "PORTALS: #{portal_keys}"
		          portal_keys.each do |portal_key|
		          	#relat = model.relationships.to_a.find{|r| storage_name = r.child_model.storage_names[:default]; portal_key.to_s == storage_name }
		          	relat = model.relationships.to_a.find{|r| storage_name = r.child_model.storage_name; portal_key.to_s == storage_name }
		          	if relat
			          	#puts "BUILDING RELATIONSHIP FROM PORTAL: #{relat.name} #{relat.child_model.name}"
			          	resources_from_portal = relat.child_model.load(record.instance_variable_get(:@portals)[portal_key], relat.child_model.query)
			          	resource.instance_variable_set(relat.instance_variable_name, resources_from_portal)
		          	end
		          end
	          rescue
	            #puts "ERROR LOADING PORTALS #{$!}"
	          end
	        end
					resource.instance_variable_set(:@_record_id, record.instance_variable_get(:@record_id))
					resource.instance_variable_set(:@_mod_id, record.instance_variable_get(:@mod_id))
				end

				resource
	    end
	  end
	end
end