# JwtAuthentication

Simple JWT token based Single Sign On for rack-based apps.

Use another app's login to provide access and user data to any rack-based application for a limited time.

NOTE: Not suitable for apps with advanced forms since it will redirect after the session timeout loosing the data.

## Config

The middleware won't do anything unless `JWT_KEY` is set.

    export JWT_KEY="a long secret key"
    export JWT_ALGORITHM="HS512"
    export JWT_SESSION_TIMEOUT_IN_SECONDS="600"
    export JWT_PARAM_MISSING_REDIRECT_URL="http://example.com/sso?app=demo"

## Example app

JwtAuthentication can be used in any rack based app. For example, see this sinatra app:

```ruby
require "sinatra"
require "jwt_authentication"

use JwtAuthentication, ignore: [
  { method: "GET", path: "/public_info" }
]

configure do
  enable :sessions
  set :session_secret, "00000" # set a better secret in a real app!
end

get "/public_info" do
  "Accessible without JWT auth"
end

get "/admin/:page" do
  # session[:jwt_user_data]["name"]

  "Only accessible after receiving a valid JWT token"
end
```

## Giving access to the app

Let's assume we have a central app where the user is logged in by some other means (e.g. username and password).

0. The user clicks a link taking them to the JWT-app.
0. The JWT-app redirects to the central app using `JWT_PARAM_MISSING_REDIRECT_URL`.
0. The central app sees that the user is logged in and has access to the JWT-app.
0. The central app generates a token using `JWT_KEY` and redirects to the JWT-app with that token, e.g. `http://example.com/?token=abc123`.
0. The JWT-app validates the token using JwtAuthentication, and if valid, gives the user access for `JWT_SESSION_TIMEOUT_IN_SECONDS`.
0. After that time, the user will be redirected to `JWT_PARAM_MISSING_REDIRECT_URL` to renew access to the JWT-app.

## Example: Authentication provider

Given that `JWT_ALGORITHM` is "HS512":

Add this to your Gemfile:

```
gem "jwt"
```

And add an endpoint similar to this:

```ruby
require "jwt"

get "/sso" do
  if current_user.logged_in?
    # app_name = params[:app]

    # NOTE: See "Security recommendations" for more secure values.
    secret = ENV.fetch("JWT_KEY")
    app_url = request.referer

    # This token is only valid for 2 seconds to prevent replay-attacks.
    payload_data = { exp: Time.now.to_i + 2, user: { name: current_user.name } }
    token = JWT.encode(payload_data, secret, "HS512")

    redirect_to "#{app_url}?token=#{token}"
  else
    redirect_to "/login"
  end
end
```

## Security recommendations

- Use a different secret key for each app so that if the key is ever exposed it can't be used to give access to any other app, e.g. `secret = app_keys.fetch(app_name)`.
- Limit redirects to known urls so that you know which apps use the centralized login, e.g. `app_url = app_urls.fetch(app_name)`.
- Consider limiting access to apps even more (e.g. all users won't need access to all external apps).
- Use as short a possible `JWT_SESSION_TIMEOUT_IN_SECONDS` as you can.
  - If you make it too short the user will be redirected to the central app all the time which slows things down.
  - If you make it too long the user will still have access to the app long after they've logged out of the central app.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
