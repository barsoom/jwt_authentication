require "spec_helper"
require "sinatra"
require "rack/test"
require "timecop"

class TestApp < Sinatra::Application
  use JwtAuthentication, ignore: [
    { method: "G*", path: "/public*" },
    "/other_public_info",
  ]

  configure do
    enable :sessions
    set :session_secret, "00000"
  end

  get "/public_info" do
    "Public info"
  end

  get "/other_public_info" do
    "Other public info"
  end

  post "/public_info" do
    raise "should not be called"
  end

  get "/data.json" do
    session[:jwt_user_data].to_json
  end

  get "/:page" do
    "Hello, world"
  end
end

class TestCustomSessionPersisterApp < Sinatra::Application
  class CustomSsoSessionPersister
    @@data = nil

    def authenticated?(session)
      @@data
    end

    def update(session, user_data)
      @@data = [ user_data, session ]
    end

    def self.forget_session
      @@data = nil
    end

    def self.data
      @@data
    end
  end

  use JwtAuthentication, sso_session_persister: CustomSsoSessionPersister.new

  configure do
    enable :sessions
    set :session_secret, "00000"
  end

  get "/:page" do
    "Hello, world"
  end
end

RSpec.describe JwtAuthentication do
  include Rack::Test::Methods

  let(:app) { TestApp }
  let(:secret_key) { "test" * 20 }
  let(:invalid_secret_key) { "test" * 20 + "." }

  before do
    ENV["JWT_SESSION_TIMEOUT_IN_SECONDS"] = "600"
    ENV["JWT_AUTH_MISSING_REDIRECT_URL"] = "http://example.com/request_jwt_auth?app=demo"
    ENV["JWT_ALGORITHM"] = "HS512"
    ENV["JWT_KEY"] = secret_key
    ENV["JWT_FAKE_REQUEST_AUTH_REDIRECT"] = nil
  end

  it "does not interfer with requests when it is not configured" do
    ENV["JWT_KEY"] = nil

    get "/foo"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("Hello, world")
  end

  it "redirects to request a login when needed" do
    get "/foo"
    expect(last_response.status).to eq(302)
    expect(last_response.header["Location"]).to eq("http://example.com/request_jwt_auth?app=demo")
  end

  it "keeps the requested url" do
    get "/foo"

    token = build_token(secret: secret_key)
    get "/?jwt_authentication_token=#{token}"
    expect(last_response.status).to eq(302)
    expect(last_response.header["Location"]).to eq("http://example.org/foo")
  end

  # In some of our apps we use this to redirect back to the main app
  # to change locale globally and then redirect to the client app with
  # the new locale data. Then we want it to go back to the URL you
  # where previously on.
  it "keeps the requested url even when already authorized" do
    token = build_token(secret: secret_key)
    get "/?jwt_authentication_token=#{token}"

    get "/foo"

    token = build_token(secret: secret_key)
    get "/?jwt_authentication_token=#{token}"
    expect(last_response.status).to eq(302)
    expect(last_response.header["Location"]).to eq("http://example.org/foo")
  end

  it "is still authenticated until the timeout" do
    token = build_token(secret: secret_key)
    get "/?jwt_authentication_token=#{token}"

    Timecop.travel 9 * 60
    get "/bar"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("Hello, world")

    # Requires new authentication after the timeout
    Timecop.travel 60
    get "/bar"
    expect(last_response.status).to eq(302)
    expect(last_response.header["Location"]).to eq("http://example.com/request_jwt_auth?app=demo")

    # Invalid token shows an error
    token = build_token(secret: invalid_secret_key)

    get "/?jwt_authentication_token=#{token}"
    expect(last_response.status).to eq(403)
  end

  it "rejects a token that is too old" do
    token = build_token(secret: secret_key)
    Timecop.travel 3
    get "/?jwt_authentication_token=#{token}"
    expect(last_response.status).to eq(403)
  end

  it "can skip some paths by config" do
    get "/public_info"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("Public info")

    get "/other_public_info"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("Other public info")

    post "/public_info"
    expect(last_response.status).to eq(302)
  end

  it "can provide data about the user" do
    token = build_token(secret: secret_key)
    get "/?jwt_authentication_token=#{token}"

    get "/data.json"
    expect(JSON.parse(last_response.body)).to eq({ "email" => "foo@example.com", "name" => "Foo" })
  end

  it "can skip the request auth redirect to make integration testing simpler" do
    ENV["JWT_FAKE_REQUEST_AUTH_REDIRECT"] = "1"

    get "/"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("JWT_FAKE_REQUEST_AUTH_REDIRECT is set, so skipping redirect to: http://example.com/request_jwt_auth?app=demo")
  end

  context "a custom sso persister" do
    let(:app) { TestCustomSessionPersisterApp }

    it "lets you decide if the user is logged in" do
      token = build_token(secret: secret_key)
      get "/?jwt_authentication_token=#{token}"

      get "/foo"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("Hello, world")

      TestCustomSessionPersisterApp::CustomSsoSessionPersister.forget_session

      get "/foo"
      expect(last_response.status).to eq(302)
      expect(last_response.header["Location"]).to eq("http://example.com/request_jwt_auth?app=demo")
    end

    it "is given user data and session" do
      token = build_token(secret: secret_key)
      get "/?jwt_authentication_token=#{token}"

      data, session = TestCustomSessionPersisterApp::CustomSsoSessionPersister.data
      expect(data.keys.sort).to eq([ "exp", "user" ])
      expect(data["user"]).to eq({ "email" => "foo@example.com", "name" => "Foo" })
      expect(session).to be_a(Rack::Session::Abstract::SessionHash)
    end
  end

  private

  def build_token(secret:)
    payload_data = { exp: Time.now.to_i + 2, user: { email: "foo@example.com", name: "Foo" }  }
    JWT.encode(payload_data, secret, "HS512")
  end
end
