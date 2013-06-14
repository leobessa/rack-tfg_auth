# Rack::TfgAuth

Rack middleware for using the Authorization header with TFG authentication.

```
TFG client="ios1.0", signature="value_a", timestamp="value_b"
```

## Usage

Add to your middleware chain, add it to `config.ru`:

``` ruby
require 'rack/tfg_auth'

use Rack::TfgAuth do |token, options, env|
  token == "my secret token"
end

run YourApp
```

If the block returns true, the rest of app will be invoked, if the block
returns false, the request will halt with a 401 (Unauthorized) response.

If you're using Rails, add to `config/environments/production.rb`:

``` ruby
config.middleware.use Rack::TfgAuth do |token, options, env|
  # etc...
end
```

### Optional configuration

The response in case of an unauthorized request can be modified, by specifying
a Rack app, like this:

``` ruby
unauthorized_app = lambda { |env| [ 401, {}, ["Please speak to our sales dep. for access"] ] }
use Rack::TfgAuth, :unauthorized_app => unauthorized_app do |token, options, env|
  # etc...
end
```

If the authorization header is malformed, the middleware chain will also be
halted and a 400 response will be returned. You can also specify this:

``` ruby
unprocessable_header_app = lambda { |env| [ 400, {}, ["You idiot!"] ] }
use Rack::TfgAuth, :unprocessable_header_app => unprocessable_header_app do |token, options, env|
  # etc...
end
```

## Installation

Add this line to your application's Gemfile:

    gem 'rack-tfg_auth'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-tfg_auth


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
