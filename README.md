# dm-filemaker-adapter

A Filemaker adapter for DataMapper, allowing DataMapper to use Filemaker Server as a datastore.

dm-filemaker-adapter uses the ginjo-rfm gem as the backend command and xml parser. Ginjo-rfm is a full featured filemaker-ruby adapter that exposes most of Filemaker's xml interface functionality in ruby. dm-filemaker-adapter doesn't tap into all of rfm's features, but rather, dm-filemaker-adapter provides DataMapper the ability to use Filemaker Server as a backend datastore. All of the basic functionality of DataMapper's CRUD interface is supported, including compound queries and 'or' queries (using Filemaker's -findquery command), query operators like :field.gt=>..., lazy-loading where possible, first & last record, aggregate queries, ranges, field mapping, and more.

## Installation

Add this line to your application's Gemfile:

    gem 'dm-filemaker-adapter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dm-filemaker-adapter

## Usage

    DB_CONFIG = {
      adapter:            'filemaker',
      host:               'my.server.com',
      account_name:       'my-user-name',
      password:           'xxxxxxxxxx',
      database:           'db-name'   
    }

    DataMapper.setup(:default, DB_CONFIG)
    
    class User
      include DataMapper::Resource
      storage_names[:default] = 'user_xml'  # This is your filemaker layout for the user table.

      # Property & field names in this list must be lowercase, regardless of what they are in Filemaker.

      property :id, Serial
      property :username, String, :length => 128, :unique => true, :required => true,
        :default => lambda {|r,v| r.instance_variable_get :@email}
      property :email, String, :length => 128, :unique => true, :required => true, :format=>:email_address
      property :updated_at, DateTime, :field=>'modification_timestamp'
      property :encrypted_password, BCryptPassword
    end

    DataMapper.finalize

		# get a specific user id
    User.get '1035'

		# first record that matches exactly 'wbr'
    User.first :email => 'wbr'

		# all records updated since 3 days ago
    User.all :updated.gt => Time.now-3*24*60*60  #=> greater than 3 days ago

		# records 10 thru 20, ordered by :id
    User.all(:order=>:id)[10..20]

		# creates 2 find requests in filemaker ('or' operation)
    User.all(:email=>'wbr', :activated_at.gt=>'1/1/1980') | User.all(:username=>'wbr', :activated_at.gt=>'1/1/1980')
    
    
    
    
    

