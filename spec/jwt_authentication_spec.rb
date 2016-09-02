require "spec_helper"
require "rack/test"

describe JwtAuthentication do
  let(:app) { proc { [ 200, {}, [ "Hello, world." ] ] } }
  let(:stack) { JwtAuthentication.new(app) }
  let(:request) { Rack::MockRequest.new(stack) }

  before do
    ENV["JWT_SESSION_TIMEOUT_IN_SECONDS"] = "600"
    ENV["JWT_PARAM_NAME"] = "token"
    ENV["JWT_PARAM_MISSING_REDIRECT_URL"] = "http://example.com/request_jwt_auth?app=demo"
    ENV["JWT_ALGORITHM"] = "HS512"
    ENV["JWT_KEY"] = secret_key
  end

  let(:secret_key) { "test" * 20 }

  it "does not interfer with requests when not configured" do
    ENV["JWT_KEY"] = nil

    response = request.get("/")
    expect(response.status).to eq(200)
    expect(response.body).to eq("Hello, world.")
  end

  it "redirects to request a login when needed" do
    response = request.get("/")
    expect(response.status).to eq(302)
    expect(response.header["Location"]).to eq("http://example.com/request_jwt_auth?app=demo")

    #p response.methods - Object.methods
    # TODO: handle sessions? request tests?
  end
end
