require "net/http"
require "json"
require "uri"

class GithubService
  class Error < StandardError
    attr_reader :status

    def initialize(status, message)
      @status = status
      super(message)
    end
  end

  AUTHORIZE_URL = "https://github.com/login/oauth/authorize".freeze
  TOKEN_URL     = "https://github.com/login/oauth/access_token".freeze
  API_BASE      = "https://api.github.com".freeze

  class << self
    def authorize_url(state:)
      raise Error.new(503, "GitHub OAuth is not configured") if client_id.blank?

      uri = URI(AUTHORIZE_URL)
      uri.query = URI.encode_www_form(
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: ENV.fetch("GITHUB_SCOPE", "repo read:user"),
        state: state
      )
      uri.to_s
    end

    def exchange_code(code)
      raise Error.new(503, "GitHub OAuth is not configured") if client_secret.blank?

      uri = URI(TOKEN_URL)
      req = Net::HTTP::Post.new(uri)
      req["Accept"] = "application/json"
      req.set_form_data(
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri
      )
      response = perform(uri, req)
      parse_json(response.body)
    end

    def user(token)
      api_request(token, Net::HTTP::Get, "/user")
    end

    def repos(token)
      api_request(token, Net::HTTP::Get, "/user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member")
    end

    def repo(token, full_name)
      api_request(token, Net::HTTP::Get, "/repos/#{encode_full_name(full_name)}")
    end

    def create_webhook(token, full_name, url, secret:, events: default_events)
      payload = {
        name: "web",
        active: true,
        events: events,
        config: {
          url: url,
          content_type: "json",
          secret: secret,
          insecure_ssl: "0"
        }
      }
      api_request(token, Net::HTTP::Post, "/repos/#{encode_full_name(full_name)}/hooks", body: payload)
    end

    def delete_webhook(token, full_name, hook_id)
      api_request(token, Net::HTTP::Delete, "/repos/#{encode_full_name(full_name)}/hooks/#{hook_id}")
    end

    private

    def default_events
      ENV.fetch("GITHUB_WEBHOOK_EVENTS", "push,pull_request").split(",").map(&:strip).reject(&:empty?)
    end

    def client_id
      ENV.fetch("GITHUB_CLIENT_ID", "")
    end

    def client_secret
      ENV.fetch("GITHUB_CLIENT_SECRET", "")
    end

    def redirect_uri
      ENV.fetch("GITHUB_REDIRECT_URI", "http://localhost:3001/api/v1/github/oauth/callback")
    end

    def encode_full_name(full_name)
      full_name.to_s.split("/").map { |seg| URI.encode_www_form_component(seg) }.join("/")
    end

    def api_request(token, klass, path, body: nil)
      uri = URI("#{API_BASE}#{path}")
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{token}"
      req["Accept"] = "application/vnd.github+json"
      req["User-Agent"] = "ExecuteHub"
      req["X-GitHub-Api-Version"] = "2022-11-28"
      if body
        req["Content-Type"] = "application/json"
        req.body = body.to_json
      end
      response = perform(uri, req)
      return nil if response.body.to_s.empty?
      parse_json(response.body)
    end

    def perform(uri, req)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      response = http.start { |h| h.request(req) }
      return response if response.is_a?(Net::HTTPSuccess)

      message = begin
        JSON.parse(response.body).dig("message")
      rescue JSON::ParserError
        nil
      end
      raise Error.new(response.code.to_i, message.presence || response.message)
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
