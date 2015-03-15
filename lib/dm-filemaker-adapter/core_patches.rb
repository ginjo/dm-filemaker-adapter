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
#     def finalize(*args)
#       property :_record_id, Integer, :lazy=>false, :field=>'record_id'
#       property :_mod_id, Integer, :lazy=>false, :field=>'mod_id'
#       finalize_orig
#     end
    
    # Loads an instance of this Model, taking into account IdentityMap lookup,
    # inheritance columns(s) and Property typecasting.
    #
    # @param [Enumerable(Object)] records
    #   an Array of Resource or Hashes to load a Resource with
    #
    # @return [Resource]
    #   the loaded Resource instance
    #
    # @api semipublic
    def load(records, query)
      repository      = query.repository
      repository_name = repository.name
      fields          = query.fields
      discriminator   = properties(repository_name).discriminator
      no_reload       = !query.reload?

      field_map = Hash[ fields.map { |property| [ property, property.field ] } ]

      records.map do |record|
        identity_map = nil
        key_values   = nil
        resource     = nil

        case record
          when Hash
            # remap fields to use the Property object
            record = record.dup
            field_map.each { |property, field| record[property] = record.delete(field) if record.key?(field) }

            model     = discriminator && discriminator.load(record[discriminator]) || self
            model_key = model.key(repository_name)
            
            #puts "MODEL_KEY #{model_key.inspect}"

            resource = if model_key.valid?(key_values = record.values_at(*model_key))
              identity_map = repository.identity_map(model)
              identity_map[key_values]
            end
            
            #puts "RESOURCE? #{resource.class}"
            #puts "KEY_VALUES #{key_values.inspect}"
            #puts "IDENTITY_MAP #{identity_map.inspect}"

            resource ||= model.allocate

            fields.each do |property|
              next if no_reload && property.loaded?(resource)

              value = record[property]

              # TODO: typecasting should happen inside the Adapter
              # and all values should come back as expected objects
              value = property.load(value)

              property.set!(resource, value)
            end

          when Resource
            model     = record.model
            model_key = model.key(repository_name)

            resource = if model_key.valid?(key_values = record.key)
              identity_map = repository.identity_map(model)
              identity_map[key_values]
            end

            resource ||= model.allocate

            fields.each do |property|
              next if no_reload && property.loaded?(resource)

              property.set!(resource, property.get!(record))
            end
        end

        resource.instance_variable_set(:@_repository, repository)

        if identity_map
          resource.persistence_state = Resource::PersistenceState::Clean.new(resource) unless resource.persistence_state?

          # defer setting the IdentityMap so second level caches can
          # record the state of the resource after loaded
          identity_map[key_values] = resource
        else
          resource.persistence_state = Resource::PersistenceState::Immutable.new(resource)
        end
        
        
        # For Testing: resource.instance_variable_set(:@record, record)
        # WBR - Loads portal data into DM model attached to this resource.
        #puts "MODEL#LOAD record #{record.class} portals #{record.portals.keys rescue 'no portals'}"
        #if record.respond_to?(:portals) && record.portals.kind_of?(Hash) && record.portals.any?
        if (portals = record.instance_variable_get(:@portals)) && portals.kind_of?(Hash) && portals.any?
          begin
          #puts record.portals.to_yaml
          #DmProduct.load(record.portals['product'].each{|r| r.instance_variable_set(:@loaded, false)}, query)
          #DmProduct.load(record.portals['product'].collect{|r| r.to_h}, query)
          #resource.instance_variable_set(:@_related_records, DmProduct.load(record.portals['product'].each{|r| r.instance_variable_set(:@loaded, false)}, DmProduct.query) )
          #tdm.class.relationships.to_a.inject({}){|r,x|  r[x.child_model.storage_names[:default]] = x.child_model; r }
          
          #assoc = relationships.to_a.inject({}){|r,x| r[x.child_model.storage_names[:default]] = x.child_model; r}
          portal_keys = portals.keys
          puts "PORTALS: #{portal_keys}"
          portal_keys.each do |portal_key|
          	relat = relationships.to_a.find{|r| storage_name = r.child_model.storage_names[:default]; portal_key.to_s == storage_name }  #puts "SN #{sn} P #{p_key}"
          	if relat
	          	puts "BUILDING RELATIONSHIP FROM PORTAL: #{relat.name} #{relat.child_model.name}"
	          	resource.instance_variable_set(relat.instance_variable_name, relat.child_model.load(record.instance_variable_get(:@portals)[portal_key], relat.child_model.query) )
          	end
          end
          rescue
            puts "ERROR LOADING PORTALS #{$!}"
          end
        end
				resource.instance_variable_set(:@_record_id, record.instance_variable_get(:@record_id))
				resource.instance_variable_set(:@_mod_id, record.instance_variable_get(:@mod_id))
				

        resource
      end
    end # load
    
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