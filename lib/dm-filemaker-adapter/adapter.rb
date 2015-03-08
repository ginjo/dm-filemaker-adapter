# Property & field names in dm-filemaker-adapter models must be declared lowercase, regardless of what they are in FMP.
require 'dm-filemaker-adapter/core_patches'
module DataMapper

  module Adapters
  
    class FilemakerAdapter < AbstractAdapter
      @fmresultset_template_path = File.expand_path('../dm-fmresultset.yml', __FILE__).to_s
      class << self; attr_accessor :fmresultset_template_path; end
      VERSION = DataMapper::FilemakerAdapter::VERSION


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
        #puts "FMP OPTIONS #{opts.inspect}"
        opts[:template] = self.class.fmresultset_template_path
        prms = query.to_fmp_query
        #puts "ADAPTER#read fmp_query built: #{prms.inspect}"
        rslt = prms.empty? ? _layout.all(opts) : _layout.find(prms, opts)
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
      


      ###  ADAPTER HELPER METHODS & UTILITIES ###

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
      	#DmProduct.last_query = attributes
      	#y attributes.operands
      	
      	
      	attributes.dup.each do |key, val|
      		if key.class.name[/Relationship/]
      			parent_keys = key.parent_key.to_a   #.collect(){|p| p.name}
      			child_keys = key.child_key.to_a     #.collect(){|p| p.name}
      			#puts "RELATIONSHIP PARENT #{key.parent_model_name} #{parent_keys.inspect}"
      			#puts "RELATIONSHIP CHILD #{key.child_model_name} #{child_keys.inspect}"
      			#puts "RELATIONSHIP CRITERIA #{val.inspect}"
      			child_keys.each_with_index do |k, i|
      				attributes[k] = val[parent_keys[i].name]
      				attributes.delete key
      			end
      		end
      	end
      	
      	# TODO: Handle attributes that have relationship components (major PITA!)
      	# q.conditions.operands.to_a[0].subject   .parent_key.collect {|p| p.name}
      	# q.conditions.operands.to_a[0].subject   .child_key.collect {|p| p.name}
      	# q.conditions.operands.to_a[0].loaded_value[child-key-name]
      	# new_attributes[child-key-name] = parent-key-value
      	
      	#puts "ATTRIBUTES BEFORE attributes_as_fields"
      	#y attributes
      	attributes_as_fields(attributes).each do |key, val|
      		#puts "EACH ATTRIBUTE class #{val.class.name}"
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
      	#puts "FM_ATTRIBUTES OUTPUT"
      	#puts fm_attributes
      	fm_attributes
      end # prepare_fmp_attributes
            
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
      
      
      
      ###  LOADED WHEN RESOURCES ARE INCLUDED  ###
      
      # Class methods extended onto model subclass.
      module ModelMethods
        def layout
          @layout ||= Rfm.layout(storage_name, repository.adapter.options.symbolize_keys)
        end
        
        # Not how to do this. Doesn't work anywhere I've tried it:
				#extend Forwardable
				#def_delegators :layout, *layout.class.instance_methods.select {|m| m.to_s[/^[a-z]/]}
      end
      
      # Instance methods included in model.
      module ResourceMethods
        def layout
          model.layout
        end
      end

    end # FilemakerAdapter
  end # Adapters
end # DataMapper
