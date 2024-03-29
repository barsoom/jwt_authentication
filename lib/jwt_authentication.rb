require "attr_extras"
require "memoit"
require "jwt"

class JwtAuthentication
  pattr_initialize :app, :options

  def call(env)
    options[:sso_session_persister] ||= begin
      timeout_in_seconds = ENV.fetch("JWT_SESSION_TIMEOUT_IN_SECONDS", 600).to_i
      TimeoutBasedSsoSessionPersister.new(timeout_in_seconds)
    end

    Request.call(app, options, env)
  end

  class TimeoutBasedSsoSessionPersister
    pattr_initialize :timeout_in_seconds

    def authenticated?(session)
      last_authenticated_time(session) &&
        (Time.now.to_i - last_authenticated_time(session) < timeout_in_seconds)
    end

    def update(session, data)
      session[:jwt_last_authenticated_time] = Time.now.to_i
      session[:jwt_user_data] = data.fetch("user")
    end

    private

    def last_authenticated_time(session)
      session[:jwt_last_authenticated_time]
    end
  end

  private

  class Request
    method_object :app, :options, :env

    def call
      return app.call(env) unless configured?
      return app.call(env) if ignored_path?

      if token
        data = verify_token
        persist_session(data)

        redirect_to_app_after_auth
      else
        remember_url

        if authenticated?
          app.call(env)
        else
          request_auth
        end
      end
    rescue JWT::DecodeError
      respond_with_unauthorized_error
    end

    def configured?
      ENV["JWT_KEY"]
    end

    def ignored_path?
      options.fetch(:ignore, []).any? { |opts|
        if opts.is_a?(Hash)
          File.fnmatch(opts.fetch(:method), request.request_method) &&
          File.fnmatch(opts.fetch(:path), request.path)
        else
          path = opts
          File.fnmatch(path, request.path)
        end
      }
    end

    def authenticated?
      sso_session_persister.authenticated?(request.session)
    end

    def persist_session(data)
      sso_session_persister.update(request.session, data)
    end

    def redirect_to_app_after_auth
      [ 302, { "Location" => url_after_auth }, [ "" ] ]
    end

    def request_auth
      if ENV["JWT_FAKE_REQUEST_AUTH_REDIRECT"]
        [ 200, {}, [ "JWT_FAKE_REQUEST_AUTH_REDIRECT is set, so skipping redirect to: #{request_auth_url}" ] ]
      else
        [ 302, { "Location" => request_auth_url }, [ "" ] ]
      end
    end

    def respond_with_unauthorized_error
      [ 403, {}, [ "Could not verify your JWT token. This means we can not give you access. Contact the sysadmin if the problem persists." ] ]
    end

    def verify_token
      data, _ = JWT.decode(token, ENV.fetch("JWT_KEY"), _verify = true, algorithm: ENV.fetch("JWT_ALGORITHM"))
      data
    end

    def url_after_auth
      request.session.delete(:url_after_jwt_authentication) || "/"
    end

    def remember_url
      request.session[:url_after_jwt_authentication] = request.url
    end

    def request_auth_url
      ENV.fetch("JWT_AUTH_MISSING_REDIRECT_URL")
    end

    def sso_session_persister
      options.fetch(:sso_session_persister)
    end

    memoize \
    def token
      # The name of this param must be something we can assume is always
      # intended for this middleware. It can't be "payload" or "token" since
      # that could be something else.
      request.params["jwt_authentication_token"]
    end

    memoize \
    def request
      ::Rack::Request.new(env)
    end
  end
end
