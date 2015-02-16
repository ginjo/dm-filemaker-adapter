# dm-filemaker-adapter

A Filemaker adapter for DataMapper, allowing DataMapper to use Filemaker Server as a datastore.

dm-filemaker-adapter uses the ginjo-rfm gem as the backend command and xml parser. Ginjo-rfm is a full featured filemaker-ruby adapter that exposes most of Filemaker's xml interface functionality in ruby. dm-filemaker-adapter doesn't tap into all of rfm's features, but rather, it provides DataMapper the ability to use Filemaker Server as a backend datastore. All of the basic functionality of DataMapper's CRUD interface is supported, including compound queries and OR queries (using Filemaker's -findquery command), query operators like :field.gt=>..., lazy-loading where possible, first & last record, aggregate queries, ranges, field mapping, and more.

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

      property :userid, String, :key=>true, :required=>false
      property :email, String
      property :login, String, :field=>'username'
      property :updated, DateTime, :field=>'updated_at'
      property :encrypted_password, BCryptPassword
    end

    DataMapper.finalize

    User.get 'usr1035'
    User.first :email => 'wbr'
    User.all :updated.gt => 3.days.ago
    
    
    
    
    

