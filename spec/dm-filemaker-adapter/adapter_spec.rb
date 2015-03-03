require 'spec_helper'

# Rspec Issues (maybe not bugs, but certainly not expected behavior!).
#
# expect/allow_any_instance_of does not work with block form of arguments in '...to receive(:message) do |args|
# The args will always just be the instance object.
#
# and_call_original breaks block form of expect.
#

# Shared Example examples:
# RSpec.shared_examples "#to_fmp_query" do
# 	it 'Receives dm query conditions and returns fmp query' do
# 		allow_any_instance_of(Rfm::Layout).to receive(:find).and_return(Rfm::Resultset.allocate)
# 		expect_any_instance_of(DataMapper::Query).to receive(:to_fmp_query).at_least(:once).and_call_original
# 		query.inspect
# 	end
# end
#
# context "with simple .all query" do
# 	include_examples "#to_fmp_query" do
# 		let(:query){User.all(:id=>1)}
# 	end
# end

describe DataMapper do
	before :each do
		DataMapper.setup(:default, 'filemaker://user:pass@hostname.com/DatabaseName')
		class ::User
			include DataMapper::Resource
			property :id, Serial
			property :email, String
			finalize
		end
	end

	describe DataMapper::Adapters::FilemakerAdapter do

	  it 'Has a version number' do
	    expect(DataMapper::Adapters::FilemakerAdapter::VERSION).not_to be nil
	  end
	
	  it 'Does something useful' do
	    expect(true).to eq(true)
	  end
	  
	  it 'Supports model classes' do
	  	expect(User.ancestors.include?(DataMapper::Adapters::FilemakerAdapter::ResourceMethods)).to eq(true)
	  end
	  
	  it 'Acts as dm database adapter for model repository' do
	  	expect(User.repository.adapter.class).to eq(DataMapper::Adapters::FilemakerAdapter)
	  end
	  
	  
	  
	  # THESE ARE ALL WRONG. They should process and return real data, instead of returning canned 'safe' responses with rspec mocking.
	  # Use .and_call_original to allow expected methods to run their original purpose.
	  # See https://github.com/rspec/rspec-mocks.
	  describe '#read' do
	  	it 'Receives dm query object with conditions' do
	  		#expect_any_instance_of(DataMapper::Adapters::FilemakerAdapter).to receive(:read).and_return(Rfm::Resultset.allocate)
				expect(User.repository.adapter).to receive(:read) do |query|
					expect(query.class).to eq(DataMapper::Query)
					expect(query.conditions.first.subject.field).to eq('id')
					expect(query.conditions.first.value).to eq(1)
				end.and_return(Rfm::Resultset.allocate)
				User.all(:id=>1).inspect
	  	end
	  end  
	  
	end # datamapper-adapters-filemaker
	
	describe DataMapper::Query do
	  
	  describe '#to_fmp_query' do
	  	# I'm passing in the example here, so we can use the metadata to construct
	  	# streamlined tests for a variety of query inputs to the to_fmp_query method.
	  	before(:each) do |example|
	  		
	  		# Not really needed yet, but helpful if calls go into Rfm.
				allow_any_instance_of(Rfm::Layout).to receive(:find).and_return(Rfm::Resultset.allocate)
				#expect_any_instance_of(DataMapper::Query).to receive(:to_fmp_query).at_least(:once).and_call_original
				
				# Capture the query object passed to the adapter#read method
				expect(DataMapper.repository.adapter).to receive(:read) do |query|
					#puts "QUERY #{query}"
					#puts "Self within before/expect block #{self}"
					@query = query
					[]
				end
				
				# Possible helpful meta info for each example.
				#puts "EXAMPLE INSTANCE VARS #{example.instance_variables.inspect}"
				#
				# Uses the desription of the example as the user query code,
				# and uses the block of the example as the expected to_fmp_query result.
				# Also replaces the description with more informative info, including the expected result.
				#
				@name = example.description.dup
				@block = example.instance_variable_get(:@example_block)
				@expected_result = @block.call
				example.description.replace "#{@name} should return #{@expected_result}"
				# Runs the query to get the query object.
				eval(@name.to_s).inspect
				@fmp_query = @query.to_fmp_query
				# All of the above, so we can do this.
				expect(@fmp_query).to eq(@expected_result)
			end
			
			it('User.all'){ {} }
			it('User.first(:id=>1)') { {'id' => '==1'} }
			it('(User.all(:id=>1) | User.all(:id=>2))') { [{"id"=>"==1"}, {"id"=>"==2"}] }

	
	  end	#to_fmp_query
	
	end # datamapper-query
	
end # datamapper
