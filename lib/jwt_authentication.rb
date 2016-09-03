require "attr_extras"
require "memoit"
require "jwt"

class JwtAuthentication
  pattr_initialize :app, :options

  def call(env)
    Request.call(app, options, env)
  end

  private

  class Request
    method_object :app, :options, :env

    def call
      return app.call(env) unless configured?
      return app.call(env) if ignored_path?
      return app.call(env) if authenticated?

      if token
        verify_token
        remember_last_authenicated_time
        redirect_to_app_after_auth
      else
        remember_url_before_auth
        request_auth
      end
    rescue JWT::DecodeError
      respond_with_unauthorized_error
    end

    def configured?
      ENV["JWT_KEY"]
    end

    def ignored_path?
      options.fetch(:ignore).any? { |opts|
        opts.fetch(:method) == request.request_method &&
        opts.fetch(:path)   == request.path
      }
    end

    def authenticated?
      timeout_in_seconds = ENV.fetch("JWT_SESSION_TIMEOUT_IN_SECONDS").to_i

      last_authenticated_time &&
        (Time.now.to_i - last_authenticated_time < timeout_in_seconds)
    end

    def redirect_to_app_after_auth
      [ 302, { "Location" => url_after_auth }, [ "" ] ]
    end

    def request_auth
      [ 302, { "Location" => request_auth_url }, [ "" ] ]
    end

    def respond_with_unauthorized_error
      [ 403, {}, [ "Could not verify your JWT token. This means we can not give you access. Contact the sysadmin if the problem persists." ] ]
    end

    def verify_token
      JWT.decode(token, ENV.fetch("JWT_KEY"), verify = true, algorithm: ENV.fetch("JWT_ALGORITHM"))
    end

    def url_after_auth
      request.session.delete(:url_after_jwt_authentication) || "/"
    end

    def last_authenticated_time
      request.session[:jwt_last_authenticated_time]
    end

    def remember_last_authenicated_time
      request.session[:jwt_last_authenticated_time] = Time.now.to_i
    end

    def remember_url_before_auth
      request.session[:url_after_jwt_authentication] = request.url
    end

    def request_auth_url
      ENV.fetch("JWT_PARAM_MISSING_REDIRECT_URL")
    end

    memoize \
    def token
      param_name = ENV.fetch("JWT_PARAM_NAME", "token")
      request.params[param_name]
    end

    memoize \
    def request
      ::Rack::Request.new(env)
    end
  end
end
