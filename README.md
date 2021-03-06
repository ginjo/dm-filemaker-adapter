# dm-filemaker-adapter

A Filemaker adapter for DataMapper, allowing DataMapper to use Filemaker Server as a datastore.

dm-filemaker-adapter uses the ginjo-rfm gem as the backend command and xml parser. Ginjo-rfm is a full featured filemaker-ruby adapter that exposes most of Filemaker's xml interface functionality in ruby. dm-filemaker-adapter doesn't tap into all of rfm's features, but rather, it provides DataMapper the ability to use Filemaker Server as a backend datastore. Most of the basic functionality of DataMapper's interface is supported, including compound queries and 'or' queries (using Filemaker's -findquery command), validations, associations, query operators like ```:field.gt=>something```, lazy-loading where possible, first & last record, aggregate queries, ranges, field mapping, and more.

## Installation

Add this line to your application's Gemfile:

    gem 'dm-filemaker-adapter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dm-filemaker-adapter

## Usage

    # ruby

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

      # Name the filemaker layout representing the table you're modeling.
      storage_names[:default] = 'user_xml'  

      # Property & field names are case-sensitive.
      property :id, Serial
      property :username, String, :length => 128, :unique => true, :required => true,
        :default => lambda {|r,v| r.instance_variable_get :@email}
      property :email, String, :length => 128, :unique => true, :required => true, :format=>:email_address
      property :updated_at, DateTime, :field=>'ModifiedAtTimestamp'
      property :encrypted_password, BCryptPassword

      has n, :orders
    end

    class Order
      include DataMapper::Resource
      storage_names[:default] = 'order_xml'
      
      property :id, Serial
      property :user_id, Integer
      property :status, String
      
      belongs_to :user
    end

    DataMapper.finalize



    # create record
      user = User.create(:email => 'abc@company.com', :username => 'abc')

    # create associated record
      user.orders.new(:status=>'draft')

    # get a specific user id
      User.get '1035'

    # first record that matches exactly 'name'
      User.first :username => 'name'

    # all records updated since 3 days ago
      User.all :updated.gt => Time.now-3*24*60*60

    # records 10 thru 20, ordered by :id (the range is resolved by filemaker, before records are returned!)
      User.all(:order => :id)[10..20]

    # filter associated records
      user.orders.all(:status=>'closed')

    # use the union operator to create 2 find requests in a filemaker 'OR' operation
      User.all(:email => 'abc@company.com', :activated_at.gt => '1/1/1980') | \
      User.all(:username => 'abc', :activated_at.gt => '1/1/1980')

    # which gets translated to the filemaker query
        User.find [
          {:email => 'abc@company.com', :activated_at => '>1/1/1980'},
          {:username => 'abc', :activated_at.gt => '>1/1/1980'}
        ]

    # use the intersection operator to combine multiple search criteria in a filemaker 'AND' operation
      User.all(:email => 'abc@company.com', :activated_at.gt => '1/1/2015') & \
      User.all(:email => 'abc@company.com', :activated_at.lt => '5/1/2015')

    # you can also write this as
      User.all(:email => 'abc@company.com', :activated_at.gt => '1/1/2015', :activated_at.lt => '5/1/2015')
    
    # both of the above get translated to the filemaker query
        User.find(:email => 'abc@company.com', :activated_at => '>1/1/2015 <5/1/2015')



