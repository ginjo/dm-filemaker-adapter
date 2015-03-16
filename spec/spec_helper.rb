$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'dm-filemaker-adapter'

DB_CONFIG = {
  adapter:            'filemaker',
  host:               'my.host.com',
  account_name:       'developer',
  password:           '12345',
  database:           'my_database',
  ssl:                'true',
  port:               443,
  root_cert:          false,
  log_actions:        false,
  log_responses:      false,
  log_parser:         false	  
}

RESULT_SET_WITH_PORTALS = File.read(File.expand_path('../data/resultset_with_portals.xml', __FILE__)).tap do |dat|
	dat.define_singleton_method(:body){self}
end


DataMapper.setup(:default, DB_CONFIG)

class User
	include DataMapper::Resource
	property :id, Serial
	property :email, String
	property :username, String
	property :activated_at, DateTime
	
	has n, :orders
end

class Order
	include DataMapper::Resource
	property :id, Serial
	property :total, Decimal
	property :user_id, Integer
	
	belongs_to :user
end

class Project
	include DataMapper::Resource
	storage_names[:default] = 'Project Data Entry New'
	property :id, String, :key=>true, :field=>'ClientPO'
	
	has n, :items
end

class Item
	include DataMapper::Resource
	storage_names[:default] = 'projectlineitems'	
	property :id, String, :key=>true, :field=>'ItemNumber'
	property :project_id, String
	
	belongs_to :project
end

DataMapper.finalize
