require 'spec_helper'

describe DataMapper do
	before :each do
		DataMapper.setup(:default, 'filemaker://user:pass@hostname.com/DatabaseName')
		class ::User
			include DataMapper::Resource
			property :id, Serial
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
	  
	  
		# describe '#fmp_query' do
		# 	before(:each){allow_any_instance_of(Rfm::Layout).to receive(:find).and_return(Rfm::Resultset.allocate)}
		# 
		# 	it 'Receives dm query conditions and returns fmp query' do
		# 		expect(User.repository.adapter).to receive(:fmp_query).at_least(3).times do |conditions|
		# 			expect(conditions.class.ancestors.include?(DataMapper::Query::Conditions::AbstractOperation)).to eq(true)
		# 		end.and_call_original
		# 		puts User.all(:id=>1).inspect
		# 		puts User.first(:id=>1).inspect
		# 		puts (User.all(:id=>1) | User.all(:id=>2)).inspect
		# 	end
		# 
		# end
	  
	  
	end # datamapper-adapters-filemaker
	
	describe DataMapper::Query do
	  
	  describe '#to_fmp_query' do
	  	before(:each){allow_any_instance_of(Rfm::Layout).to receive(:find).and_return(Rfm::Resultset.allocate)}
	  
	  	it 'Receives dm query conditions and returns fmp query' do
				expect_any_instance_of(DataMapper::Query).to receive(:to_fmp_query).at_least(:once) do |conditions|
					expect(conditions.class.ancestors.include?(DataMapper::Query::Conditions::AbstractOperation)).to eq(true)
				end.and_call_original
				User.all(:id=>1).inspect
				#puts User.first(:id=>1).inspect
				#puts (User.all(:id=>1) | User.all(:id=>2)).inspect
	  	end
	
	  end	#to_fmp_query
	
	end # datamapper-query
	
end # datamapper
