require 'rack/tfg_auth/version'
require 'base64'
require 'openssl'

module Rack
  class TfgAuth

    UnprocessableHeader = Class.new(ArgumentError)

    def initialize(app, options = {}, &block)
      @app     = app
      @options = options
      @block   = block || method(:default_block)
    end

    def call(env)
      signature, options = *token_and_options(env["HTTP_AUTHORIZATION"])
      if @block.call(signature, options, env)
        @app.call(env)
      else
        unauthorized_app.call(env)
      end
    rescue UnprocessableHeader
      unprocessable_header_app.call(env)
    end

    def unauthorized_app
      @options.fetch(:unauthorized_app) { default_unauthorized_app }
    end

    def unprocessable_header_app
      @options.fetch(:unprocessable_header_app) { default_unprocessable_header_app }
    end

    def default_unprocessable_header_app
      lambda { |env| Rack::Response.new("Unprocessable Authorization header", 400) }
    end

    def default_unauthorized_app
      lambda { |env| Rack::Response.new("Unauthorized", 401) }
    end

    # Taken and adapted from Rails
    # https://github.com/rails/rails/blob/master/actionpack/lib/action_controller/metal/http_authentication.rb
    def token_and_options(header)
      token = header.to_s.match(/^TFG (.*)/) { |m| m[1] }
      if token
        begin
          values = Hash[token.split(%r/"(?:,|;|\s)\s*/).map do |value|
            value.strip!                         # remove any spaces between commas and values
            key, value = value.split(%r/=(.+)?/) # split key=value pairs
            value.chomp!('"')                    # chomp trailing " in value
            value.gsub! %r/^"|"$/, ''            # unescape remaining quotes
            [key.to_sym, value]
          end]
          [values.delete(:signature), values]
        rescue => error
          raise UnprocessableHeader, error
        end
      else
        [nil,{}]
      end
    end

    private
    def default_block(signature, options, env)
      return false unless signature && options && options[:client] && options[:timestamp]
      return false unless valid_timestamp?(options[:timestamp])
      secret = secret_for_client(options[:client])
      return false unless secret
      signature == expected_signature(secret,env,options)
    end

    def expected_signature(secret,env,options)      
      string_to_sign = build_string_to_sign(env, options)
      hmac_signature(secret, string_to_sign)
    end

    def valid_timestamp?(timestamp)
      client_time = timestamp.to_i
      now = @options.fetch(:now){ Time.now.to_i }
      time_abs_diff   = (now - client_time).abs
      (time_abs_diff < (4 * 3600))
    end

    def secret_for_client(client)
      @options.fetch(:client_secrets) { Hash.new }[client]
    end

    def build_string_to_sign(env, options)
      req = Rack::Request.new(env)
      string = [
          req.request_method,
          options[:client],
          options[:timestamp],
          options[:user_id],
          req.url.split('?').first,
          req.body.read
      ].compact.join("\n")
      req.body.rewind
      string
    end

    def hmac_signature(secret, string_to_sign)
      @digest ||= OpenSSL::Digest::Digest.new('sha256')
      Base64.encode64(OpenSSL::HMAC.digest(@digest, secret, string_to_sign)).chomp
    end
end
end
