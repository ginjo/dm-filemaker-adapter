# Property & field names in dm-filemaker-adapter models must be declared lowercase, regardless of what they are in FMP.

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
	    	puts "FMP_QUERY OrOperation #{input.class}"
	      input.operands.collect do |o|
	      	r = to_fmp_query o
	      	"FMP_QUERY or-operation operand #{r}"
	      	r
	      end
	    elsif input.class.name[/AndOperation/]
	    	puts "FMP_QUERY AndOperation #{input.class}"
	    	out = {}
	      input.operands.each do |k,v|
	        r = to_fmp_query(k).to_hash
	        puts "FMP_QUERY and-operation operand #{r}"
	        if r.is_a?(Hash)
	        	puts "FMP_QUERY and-operation operand is a hash"
	          out.merge!(r)
	        else
	        	puts "FMP_QUERY and-operation operand is NOT a hash"
	          out = r
	          break
	        end
	      end
	      out
	    elsif input.class.name[/NullOperation/] || input.nil?
	      puts "FMP_QUERY NullOperation #{input.class}"
	      {}
	    else
	      puts "FMP_QUERY else #{input.class}"
	      puts "FMP_QUERY else-options #{self.options.inspect}"
	      #prepare_fmp_attributes({input.subject=>input.value}, :prepend=>fmp_operator(input.class.name))
	      value = (self.options[input.subject.name] ||
	      	self.options.find{|o,v| o.respond_to?(:target) && o.target.to_s == input.subject.name.to_s}[1] ||
	      	input.value
	      ) rescue (puts "ERROR #{$!}"; input.value)
	      puts "FMP_QUERY else-value #{value}"
	      repository.adapter.prepare_fmp_attributes({input.subject=>value}, :prepend=>fmp_operator(input.class.name))
	    end
	    puts "FMP_QUERY output #{rslt.inspect}"
	    rslt
	  end # to_fmp_query
	  
		# Convert operation class to operator string
		def fmp_operator(operation)
		  case
		  when operation[/EqualTo/]; '='
		  when operation[/GreaterThan/]; '>'
		  when operation[/LessThan/]; '<'
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



  module Adapters
  
    class FilemakerAdapter < AbstractAdapter
      @fmresultset_template_path = File.expand_path('../dm-fmresultset.yml', __FILE__).to_s
      class << self; attr_accessor :fmresultset_template_path; end
      VERSION = DataMapper::FilemakerAdapter::VERSION
    
    
      ###  UTILITY METHODS  ###
    
      # Class methods extended onto model.
      module ModelMethods
        def layout
          @layout ||= Rfm.layout(storage_name, repository.adapter.options.symbolize_keys)
        end
      end
      
      # Instance methods included in model.
      module ResourceMethods
        def layout
          model.layout
        end
      end
  


      ###  ADAPTER CORE METHODS  ###

      # Persists one or many new resources
      #
      # @example
      #   adapter.create(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Enumerable<Resource>] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        resources[0].model.last_query = resources
        counter = 0
        resources.each do |resource|
          fm_params = prepare_fmp_attributes(resource.dirty_attributes)
          rslt = layout(resource.model).create(fm_params, :template=>self.class.fmresultset_template_path)
          merge_fmp_response(resource, rslt[0])
          counter +=1
        end
        counter
      end

      # Reads one or many resources from a datastore
      #
      # @example
      #   adapter.read(query)  # => [ { 'name' => 'Dan Kubb' } ]
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Query] query
      #   the query to match resources in the datastore
      #
      # @return [Enumerable<Hash>]
      #   an array of hashes to become resources
      #
      # @api semipublic
      # def read(query)
      #   raise NotImplementedError, "#{self.class}#read not implemented"
      # end
      #
      def read(query)
        query.model.last_query = query
        #y query
        _layout = layout(query.model)
        opts = query.fmp_options
        puts "FMP OPTIONS #{opts.inspect}"
        opts[:template] = self.class.fmresultset_template_path
        prms = query.to_fmp_query
        puts "ADAPTER#read fmp_query built: #{prms.inspect}"
        rslt = prms.empty? ? _layout.all(opts) : _layout.find(prms, opts.merge!(:max_records=>10))
        rslt.dup.each_with_index(){|r, i| rslt[i] = r.to_h}
        rslt
      end
      
      # Takes a query and returns number of matched records.
      # An empty query will return the total record count
      def aggregate(query)
        query.model.last_query = query
        #y query
        _layout = layout(query.model)
        opts = query.fmp_options
        opts[:template] = self.class.fmresultset_template_path
        prms = fmp_query(query.conditions)
        #[prms.empty? ? _layout.all(:max_records=>0).foundset_count : _layout.count(prms)]
        [prms.empty? ? _layout.view.total_count : _layout.count(prms)]
      end

      # Updates one or many existing resources
      #
      # @example
      #   adapter.update(attributes, collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        collection[0].model.last_query = [attributes, collection]
        fm_params = prepare_fmp_attributes(attributes)
        counter = 0
        collection.each do |resource|
          rslt = layout(resource.model).edit(resource.record_id, fm_params, :template=>self.class.fmresultset_template_path)
          merge_fmp_response(resource, rslt[0])
          resource.persistence_state = DataMapper::Resource::PersistenceState::Clean.new resource
          counter +=1
        end
        counter        
      end

      # Deletes one or many existing resources
      #
      # @example
      #   adapter.delete(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        counter = 0
        collection.each do |resource|
          rslt = layout(resource.model).delete(resource.record_id, :template=>self.class.fmresultset_template_path)
          counter +=1
        end
        counter
      end
      


      ###  ADAPTER HELPER METHODS  ###

      # Create fmp layout object from model object.
      def layout(model)
        #Rfm.layout(model.storage_name, options.symbolize_keys)   #query.repository.adapter.options.symbolize_keys)
        model.layout
      end

      def prepare_fmp_attributes(attributes, *args)
      	options = args.last.is_a?(Hash) ? args.pop : {}
      	prepend, append = options[:prepend], options[:append]
      	fm_attributes = {}
      	#puts "PREPARE FMP ATTRIBUTES"
      	#y attributes
      	attributes_as_fields(attributes).each do |key, val|
      		#puts "EACH ATTRIBUTE class #{val.class}"
      		#puts "EACH ATTRIBUTE value #{val}"
      		new_val = val && [val.is_a?(Fixnum) ? val : val.dup].flatten.inject([]) do |r, v|
      			#puts "INJECTING v"
      			#puts v
      			new_v = v.respond_to?(:_to_fm) ? v._to_fm : v
      			#puts "CONVERTING VAL #{new_val} TO STRING"
      			new_v = new_v.to_s
      			#puts "PREPENDING #{new_v} with '#{prepend}'"
      			new_v.prepend prepend if prepend rescue nil
      			new_v.append append if append rescue nil
      			r << new_v
      		end
      		#puts "NEW_VAL"
      		#puts new_val
      		fm_attributes[key] = (new_val && new_val.size < 2) ? new_val[0] : new_val
      	end
      	#puts "FM_ATTRIBUTES"
      	#puts fm_attributes
      	fm_attributes
      end
            
      def merge_fmp_response(resource, record)
        resource.model.properties.to_a.each do |property|
          if record.key?(property.field.to_s)
            resource[property.name] = record[property.field.to_s]
          end
        end     
      end
      
      # # This is supposed to convert property objects to field name. Not sure if it works.
      # def get_field_name(field)
      #   return field.field if field.respond_to? :field
      #   field
      # end
            

      protected :merge_fmp_response   #,:fmp_options, :prepare_fmp_attributes, :fmp_operator,:fmp_query

    end # FilemakerAdapter
  end # Adapters
end # DataMapper

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

