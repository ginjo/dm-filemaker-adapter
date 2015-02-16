# dm-filemaker-adapter

This datastore adapter for DataMapper provides all of DataMapper's basic CRUD operations
using Filemaker as the datastore.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dm-filemaker-adapter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dm-filemaker-adapter

## Usage

You must also install the Filemaker-to-ruby gem 'ginjo-rfm .
dm-filemaker-adapter uses rfm to handle the underlying calls to Filemaker server and the parsing of the xml responses.

So, a simple yet functional Gemfile would look something like this.
		gem 'data_mapper'
		gem 'dm-filemaker-adapter'
		gem 'ginjo-rfm'
		
Ginjo-rfm will use the built-in ruby xml parser, REXML, unless you install one of the other supported parsers.
		gem 'data_mapper'
		gem 'dm-filemaker-adapter'
		gem 'ginjo-rfm'
		
		gem 'ox'  # or 'nokogiri' or 'libxml-ruby'



## Contributing

1. Fork it ( https://github.com/[my-github-username]/dm-filemaker-adapter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
