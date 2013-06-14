require 'rack'
require 'rack/tfg_auth'

class Fixnum
  def hours
    self * 3600
  end
  def minutes
    self * 60
  end
  def second
    self
  end
end
describe Rack::TfgAuth do

  Endpoint = Rack::Response.new("OK")

  describe "parsing the authorization header" do

    let(:block) { lambda { |token| } }
    let(:app) { build_app(&block) }

    it "evaluates the block with token and options" do
      env = { "HTTP_AUTHORIZATION" => %(TFG signature="abc", foo="bar") }
      block.should_receive(:call).with("abc", {:foo => "bar"}, env)
      app.call(env)
    end

    it "handles absent header" do
      env = {}
      block.should_receive(:call).with(nil, {}, env)
      app.call(env)
    end

    it "handles other authorization header" do
      env = { "HTTP_AUTHORIZATION" => %(Basic QWxhZGluOnNlc2FtIG9wZW4=) }
      block.should_receive(:call).with(nil, {}, env)
      app.call(env)
    end

    it "handles misformed authorization header" do
      block.should_not_receive(:call)
      result = app.call("HTTP_AUTHORIZATION" => %(TFG foobar))
      result.status.should eq 400
    end

    it "allows specifying the unprocessable header app" do
      unprocessable_header_app = mock :unprocessable_header_app
      app = build_app(:unprocessable_header_app => unprocessable_header_app)

      unprocessable_header_app.should_receive(:call)
      app.call("HTTP_AUTHORIZATION" => %(TFG foobar))
    end

  end

  context "when block returns false" do

    let(:env) { mock :env, :[] => true }

    it "doesn't call the rest of the app" do
      app = build_app do false end
      Endpoint.should_not_receive(:call)
      app.call(env)
    end

    it "has a default response" do
      app = build_app do false end
      result = app.call(env)
      result.body.should eq ["Unauthorized"]
      result.status.should eq 401
    end

    it "is able to set the unauthorized app" do
      unauthorized_app = mock :unauthorized_app
      app = build_app :unauthorized_app => unauthorized_app do false end

      unauthorized_app.should_receive(:call).with(env)
      app.call(env)
    end

  end

  context "default block" do
    it "denies access to requests without authorization header" do
      app = build_app
      result = app.call({})
      result.status.should eq 401
    end
    it "accepts access to requests that are almost 4 hours old" do
      now = Time.utc(2013,6,14,12).to_i
      app = build_app(:now => now, :client_secrets => {"fake" => "secret"})
      client_time = (now - 4.hours + 1.second).to_i
      env = {
        "HTTP_AUTHORIZATION" => %(TFG signature="HGPBSMJWistgrkOKYxfVhhrZ7X4SBPUjmuVyn36ywP0=", client="fake", timestamp="#{client_time}"),
        "rack.input" => StringIO.new
      }
      Endpoint.should_receive(:call).with(env)
      result = app.call(env)
    end
    it "rejects access to requests that are more than 4 hours old" do
      now = Time.utc(2013,6,14,12).to_i
      app = build_app(:now => now, :client_secrets => {"fake" => "secret"})
      client_time = (now - 4.hours - 1.second).to_i
      env = {
        "HTTP_AUTHORIZATION" => %(TFG signature="hb0aXg2DL3I+VrfvGH7vm1DkgFF1l7e6rdbemoE2q1s=", client="fake", timestamp="#{client_time}"),
        "rack.input" => StringIO.new
      }
      result = app.call(env)
      result.status.should eq 401
    end

    def signature(string_to_sign)
      digest = OpenSSL::Digest::Digest.new('sha256')
      Base64.encode64(OpenSSL::HMAC.digest(digest, "my-shared-secret", string_to_sign)).chomp
    end

    [:get, :post, :put].each do |method|
      it "accepts request using a valid signature via #{method.upcase}" do
        now = Time.utc(2013,6,14,12).to_i
        app = build_app(:now => now, :client_secrets => {"fake_client" => "my-shared-secret"})
        body = method == :get ? '' : 'mybodydata'
        string_to_sign = [
            method.upcase,
            'fake_client',
            now.to_s,
            'http://example.org/signature/test.json',
            body
        ].compact.join("\n")
        env = {
          "REQUEST_METHOD" => method.to_s.upcase,
          "rack.url_scheme" => "http",
          "HTTP_HOST" => "example.org",
          "SERVER_PORT" => "80",
          "PATH_INFO" => "/signature/test.json",
          "rack.input" => StringIO.new(body),
          'HTTP_AUTHORIZATION' => %(TFG client="fake_client", signature="#{signature(string_to_sign)}", timestamp="#{now}")
        }
        Endpoint.should_receive(:call).with(env)
        result = app.call(env)
      end
    end

  end

  context "when the block returns true" do

    let(:env) { mock :env, :[] => true }

    it "calls the rest of your app" do
      app = build_app do true end
      Endpoint.should_receive(:call).with(env)
      app.call(env)
    end

  end

  def build_app(*args, &block)
    Rack::Builder.new {
      use Rack::TfgAuth, *args, &block
      run Endpoint
    }
  end

end
