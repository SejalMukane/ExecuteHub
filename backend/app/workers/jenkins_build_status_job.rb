# JenkinsBuildStatusJob polls Jenkins for a Build's status when ExecuteHub
# triggered the Jenkins job itself (the reverse direction of the Jenkinsfile
# callback flow). It is deliberately light:
#
#   - NO continuous polling: it re-enqueues itself at most poll_max_attempts
#     times with exponential backoff (5s -> 10s -> 20s -> 40s, capped).
#   - It stops as soon as the Jenkins build reaches a terminal state
#     (passed/failed/cancelled/error) and funnels that result through
#     JenkinsBuildCallbackService so the Build/Pipeline transition logic stays
#     in exactly one place.
#   - A Jenkins outage (timeout/connection/auth) never crashes the job — it
#     just bumps the attempt counter and backs off again.
class JenkinsBuildStatusJob
  include Sidekiq::Worker

  sidekiq_options queue: "jenkins", retry: false, backtrace: true

  TERMINAL_STATES = %w[passed failed cancelled error].freeze
  MAX_BACKOFF_SECONDS = 40

  def self.schedule(build_id)
    initial = JenkinsBuildStatusJob.jenkins_config[:poll_interval_seconds].to_i
    perform_in(initial.positive? ? initial : 5, build_id, 1)
  end

  def perform(build_id, attempt = 1)
    build = Build.find_by(id: build_id)
    return unless build
    return unless build.status == "running"

    state = poll(build, attempt)
    if TERMINAL_STATES.include?(state)
      apply_terminal(build, state)
    else
      reschedule(build, attempt)
    end
  rescue JenkinsHttpClient::Error => e
    Rails.logger.warn("[JenkinsBuildStatusJob] Poll for build ##{build_id} failed " \
                      "(try #{attempt}/#{max_attempts}): #{e.message}")
    reschedule(build, attempt)
  end

  private

  def poll(build, _attempt)
    info = JenkinsService.build_status(build.jenkins_build_number)
    derived_started_at = info[:started_at]
    build.update_column(:started_at, derived_started_at) if derived_started_at && build.started_at.nil? && !build.finished_at
    info[:state]
  end

  def apply_terminal(build, state)
    JenkinsBuildCallbackService.call(build: build, jenkins_status: state)
  end

  def reschedule(build, attempt)
    return log_stopping(build, attempt) if attempt >= max_attempts

    delay = backoff_seconds(attempt)
    Rails.logger.info("[JenkinsBuildStatusJob] Build ##{build.id} still #{build.status}; " \
                      "re-polling in #{delay}s (attempt #{attempt}/#{max_attempts})")
    self.class.perform_in(delay, build.id, attempt + 1)
  end

  def backoff_seconds(attempt)
    base = jenkins_config[:poll_interval_seconds].to_i
    base = 5 if base <= 0
    [base * (2**(attempt - 1)), MAX_BACKOFF_SECONDS].min
  end

  def max_attempts
    jenkins_config[:poll_max_attempts].to_i
  end

  def self.jenkins_config
    Rails.configuration.executehub[:jenkins] || {}
  end

  def jenkins_config
    self.class.jenkins_config
  end

  def log_stopping(build, attempt)
    Rails.logger.warn("[JenkinsBuildStatusJob] Build ##{build.id} still not terminal after " \
                      "#{attempt} polls; stopping. A later callback can still settle it.")
  end
end