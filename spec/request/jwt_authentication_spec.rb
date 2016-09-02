require "spec_helper"
require "sinatra"
require "rack/test"
require "timecop"

class TestApp < Sinatra::Application
  use JwtAuthentication, except: /public_info/

  configure do
    enable :sessions
    set :session_secret, "00000"
  end

  get "/public_info" do
    "Public info"
  end

  get "/:page" do
    "Hello, world"
  end
end

describe JwtAuthentication do
  include Rack::Test::Methods

  let(:app) { TestApp }
  let(:secret_key) { "test" * 20 }
  let(:invalid_secret_key) { "test" * 20 + "." }

  before do
    ENV["JWT_SESSION_TIMEOUT_IN_SECONDS"] = "600"
    ENV["JWT_PARAM_NAME"] = "token"
    ENV["JWT_PARAM_MISSING_REDIRECT_URL"] = "http://example.com/request_jwt_auth?app=demo"
    ENV["JWT_ALGORITHM"] = "HS512"
    ENV["JWT_KEY"] = secret_key
  end

  it "does not interfer with requests when not configured" do
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
    get "/?token=#{token}"
    expect(last_response.status).to eq(302)
    expect(last_response.header["Location"]).to eq("http://example.org/foo")
  end

  it "is still authenticated until the timeout" do
    token = build_token(secret: secret_key)
    get "/?token=#{token}"

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

    get "/?token=#{token}"
    expect(last_response.status).to eq(403)
  end

  it "can skip some paths by config" do
    get "/public_info"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("Public info")
  end

  private

  def build_token(secret:)
    payload_data = { exp: Time.now.to_i + 2 }
    JWT.encode(payload_data, secret, "HS512")
  end
end
