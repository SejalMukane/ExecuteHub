require "net/http"
require "json"
require "uri"

# JenkinsHttpClient is the reusable, low-level HTTP layer used by
# JenkinsService. It owns every Jenkins-specific transport concern:
#
#   - HTTP Basic authentication (username + API token)
#   - CSRF crumb handling for unsafe requests when the server requires it
#   - JSON (de)serialization and URL building for job / build paths
#   - Mapping HTTP failures to typed exceptions (401/403/404/429/5xx)
#   - Timeout and connection-failure mapping
#
# JenkinsService is the only class that talks to Jenkins API *functionally*;
# controllers never build HTTP requests against Jenkins. This client stays
# generic enough to be reused by future CI providers' transports if needed.
class JenkinsHttpClient
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class UnauthorizedError < Error; end
  class ForbiddenError < Error; end
  class NotFoundError < Error; end
  class RateLimitedError < Error; end
  class ServerError < Error; end
  class TimeoutError < Error; end
  class ConnectionError < Error; end

  CRUMB_ISSUER_PATH = "/crumbIssuer/api/json".freeze

  attr_reader :base_url, :username, :api_token

  def initialize(base_url:, username:, api_token:, csrf_crumb_enabled: true,
                 open_timeout: 10, read_timeout: 30)
    @base_url = base_url.to_s.chomp("/")
    @username = username
    @api_token = api_token
    @csrf_crumb_enabled = csrf_crumb_enabled
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    validate_config!
  end

  # GET a Jenkins API path, returning the parsed JSON body.
  def get(path)
    send_request(:get, path)
  end

  # POST a Jenkins API path (used to trigger builds, stop builds, ...).
  # Returns parsed JSON body when present.
  def post(path, body: nil)
    send_request(:post, path, body: body)
  end

  # Jenkins "buildWithParameters" (and "build") expect application/x-www-form-urlencoded
  # parameters rather than JSON, so they get their own transport helper.
  def post_form(path, form_data = {})
    send_request(:post, path, body: URI.encode_www_form(form_data),
                              content_type: "application/x-www-form-urlencoded")
  end

  # DELETE a Jenkins API path.
  def delete(path)
    send_request(:delete, path)
  end

  # Whether any Bootstrapping config is present (Jenkins credentials exist).
  def configured?
    base_url.present? && username.present? && api_token.present?
  end

  private

  def send_request(method, path, body: nil, content_type: nil)
    raise ConfigurationError, "Jenkins is not configured (set JENKINS_URL, JENKINS_USERNAME and JENKINS_API_TOKEN)" unless configured?

    uri = URI.join("#{base_url}/", path.sub(%r{\A/}, ""))
    request = build_request(method, uri, body, content_type: content_type)
    add_auth(request)
    add_crumb(request) if unsafe?(method)

    response = perform(uri, request)
    parse_response(response)
  rescue Error
    raise
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError, "Jenkins request to #{uri} timed out: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, IOError => e
    raise ConnectionError, "Could not reach Jenkins at #{base_url}: #{e.message}"
  end

  def build_request(method, uri, body, content_type: nil)
    klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
    request = klass.new(uri)
    request["Accept"] = "application/json"
    request["User-Agent"] = "ExecuteHub"
    if body
      request["Content-Type"] = content_type || "application/json"
      request.body = body.is_a?(String) ? body : body.to_json
    end
    request
  end

  # Jenkins authenticates with the user's API token used as the password in
  # HTTP Basic auth. Standard Basic auth is base64(username:token).
  def add_auth(request)
    request.basic_auth(username, api_token)
  end

  # Jenkins CSRF protection: fetch a crumb and attach it to unsafe requests.
  # When crumb fetching fails (e.g. protection disabled or a reverse proxy
  # guards /crumbIssuer) we fall back to an uncrumbed request rather than
  # failing hard — the server either accepts it or returns 403, which is
  # mapped to ForbiddenError by the caller.
  def add_crumb(request)
    return unless @csrf_crumb_enabled

    crumb = fetch_crumb
    return unless crumb

    field = crumb["crumbRequestField"] || "Jenkins-Crumb"
    request[field] = crumb["crumb"]
  end

  def fetch_crumb
    response = perform(build_uri(CRUMB_ISSUER_PATH), build_request(:get, build_uri(CRUMB_ISSUER_PATH), nil).tap { |r| add_auth(r) })
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue Error, JSON::ParserError
    nil
  end

  def build_uri(path)
    URI.join("#{base_url}/", path.sub(%r{\A/}, ""))
  end

  def unsafe?(method)
    %i[post delete].include?(method)
  end

  def perform(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.start { |conn| conn.request(request) }
  end

  def parse_response(response)
    case response
    when Net::HTTPSuccess
      parse_body(response)
    when Net::HTTPUnauthorized
      raise UnauthorizedError, "Invalid Jenkins credentials (401)"
    when Net::HTTPForbidden
      raise ForbiddenError, "Access to Jenkins resource denied (403)"
    when Net::HTTPNotFound
      raise NotFoundError, "Jenkins resource not found (404)"
    when Net::HTTPTooManyRequests
      raise RateLimitedError, "Jenkins rate limit exceeded (429)"
    when Net::HTTPServerError
      raise ServerError, "Jenkins server error (#{response.code}): #{response.message}"
    else
      raise Error, "Unexpected Jenkins response (#{response.code}): #{response.message}"
    end
  end

  def parse_body(response)
    body = response.body
    return nil if body.nil? || body.strip.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  def validate_config!
    if base_url.present? && !base_url.start_with?("http://", "https://")
      raise ConfigurationError, "JENKINS_URL must start with http:// or https://"
    end
  end
end