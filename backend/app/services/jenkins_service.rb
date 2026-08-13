require "uri"

# JenkinsService is the ONLY entry point for Jenkins integration in ExecuteHub.
# Controllers, workers and jobs never build Jenkins HTTP requests — they call
# these class-level methods, and all Jenkins transport details stay inside this
# service (and its JenkinsHttpClient).
#
# Responsibilities:
#   - Trigger a Jenkins job
#   - Query a Jenkins build's status
#   - Retrieve Jenkins build information
#   - Cancel a Jenkins build
#   - Surface typed Jenkins errors to the caller
#
# Configuration comes exclusively from environment variables and NEVER from
# code or the database:
#
#   JENKINS_URL          e.g. http://localhost:8080
#   JENKINS_USERNAME     Jenkins user with read/trigger rights
#   JENKINS_API_TOKEN    that user's API token
#   JENKINS_JOB_NAME     job to trigger, e.g. "ExecuteHub-App" or "Folder/ExecuteHub-App"
#
# All requests go through JenkinsHttpClient, which handles Basic auth, CSRF
# crumbs, JSON parsing and error mapping (401 -> UnauthorizedError, etc).
class JenkinsService
  class Error < JenkinsHttpClient::Error; end
  class ConfigurationError < JenkinsHttpClient::ConfigurationError; end
  class UnauthorizedError < JenkinsHttpClient::UnauthorizedError; end
  class ForbiddenError < JenkinsHttpClient::ForbiddenError; end
  class NotFoundError < JenkinsHttpClient::NotFoundError; end
  class RateLimitedError < JenkinsHttpClient::RateLimitedError; end
  class ServerError < JenkinsHttpClient::ServerError; end
  class TimeoutError < JenkinsHttpClient::TimeoutError; end
  class ConnectionError < JenkinsHttpClient::ConnectionError; end

  MAX_PARAM_SIZE = 40

  class << self
    # Whether Jenkins credentials are provided for this process.
    def configured?
      build_client.configured?
    end

    # Trigger the configured Jenkins job. Returns a hash with the job name and
    # params submitted. Jenkins does not return the new build number from the
    # trigger call, so callers should follow up with #latest_build.
    def trigger_build(params: {}, client: nil)
      client ||= build_client
      job = job_name
      raise ConfigurationError, "JENKINS_JOB_NAME is not configured" if job.blank?

      if params.any?
        client.post_form(job_path(job, ["buildWithParameters"]), stringified(params))
      else
        client.post(job_path(job, ["build"]))
      end
      { job: job, params: params }
    end

    # Normalized status for a specific build:
    #   { number, building, result, state, started_at, duration, url }
    # state maps Jenkins results onto our Build statuses:
    #   running/passed/failed/cancelled/error.
    def build_status(build_number, client: nil)
      client ||= build_client
      info = build_info(build_number, client: client)
      normalize_status(info)
    end

    # Raw Jenkins build information (the /job/<job>/<build>/api/json payload).
    def build_info(build_number, client: nil)
      client ||= build_client
      client.get(build_path(build_number))
    end

    # The most recent build number for the job, or nil when no build ran yet.
    def latest_build(client: nil)
      client ||= build_client
      info = client.get(job_path(job_name, ["api", "json"]))
      info.dig("nextBuildNumber") ? info["nextBuildNumber"] - 1 : nil
    rescue NotFoundError
      nil
    end

    # Abort a running Jenkins build.
    def cancel_build(build_number, client: nil)
      client ||= build_client
      client.post(build_path(build_number, ["stop"]))
      { cancelled: build_number }
    end

    # Attach a short human-readable description to a build (used to surface
    # the ExecuteHub test result inside Jenkins). Best-effort; NotFoundError
    # and ForbiddenError are swallowed so a read-only Jenkins token never
    # breaks the pipeline.
    def set_build_description(build_number, description, client: nil)
      client ||= build_client
      client.post_form(build_path(build_number, ["submitDescription"]), description: description)
    rescue JenkinsService::NotFoundError, JenkinsService::ForbiddenError
      # Best-effort: some Jenkins users are read-only.
    end

    # Jenkins URL for a specific build.
    def build_url(build_number)
      "#{base_url}#{build_path(build_number)}"
    end

    # ----------------------------------------------------------------------
    # Configuration (env only — never hardcode).
    # ----------------------------------------------------------------------
    def base_url
      ENV.fetch("JENKINS_URL", "")
    end

    def username
      ENV.fetch("JENKINS_USERNAME", "")
    end

    def api_token
      ENV.fetch("JENKINS_API_TOKEN", "")
    end

    def job_name
      ENV.fetch("JENKINS_JOB_NAME", "")
    end

    # A freshly configured HTTP client for the current environment.
    def build_client
      settings = Rails.configuration.executehub.fetch("jenkins", {})
      JenkinsHttpClient.new(
        base_url: base_url,
        username: username,
        api_token: api_token,
        csrf_crumb_enabled: settings.fetch("csrf_crumb_enabled", true),
        open_timeout: settings.fetch("open_timeout_seconds", 10).to_i,
        read_timeout: settings.fetch("read_timeout_seconds", 30).to_i
      )
    end

    private

    # Builds a Jenkins API path for a given build, e.g. /job/App/42/api/json.
    def build_path(build_number, suffix = ["api", "json"])
      job_path(job_name, [build_number.to_s] + suffix)
    end

    # Encodes a (possibly nested, "Folder/Job") Jenkins job name into its
    # URL path form: each segment becomes /job/<segment>. Each segment is
    # percent-encoded so spaces and slashes in names are safe.
    def job_path(job, suffixes)
      segments = job.to_s.split("/").map do |segment|
        "job/#{URI.encode_www_form_component(segment)}"
      end
      "/#{segments.join("/")}#{suffixes.empty? ? "" : "/#{suffixes.map { |s| URI.encode_www_form_component(s) }.join("/")}"}"
    end

    def stringified(params)
      params.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
    end

    def normalize_status(info)
      building = info["building"]
      result = info["result"]
      state =
        if building
          "running"
        else
          case result
          when "SUCCESS" then "passed"
          when "FAILURE", "UNSTABLE" then "failed"
          when "ABORT" then "cancelled"
          else "error"
          end
        end

      {
        number: info["number"],
        building: building,
        result: result,
        state: state,
        started_at: info["timestamp"] ? Time.zone.at(info["timestamp"] / 1000) : nil,
        duration: info["duration"],
        url: info["url"]
      }
    end
  end
end