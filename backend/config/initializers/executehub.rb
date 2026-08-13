# Env-driven overrides for config/executehub.yml defaults. Only paths that
# need runtime/secret values go here; Jenkins credentials (JENKINS_URL,
# JENKINS_USERNAME, JENKINS_API_TOKEN, JENKINS_JOB_NAME) are read inside
# JenkinsService directly from ENV.
if (secret = ENV["JENKINS_CALLBACK_SECRET"].presence)
  jenkins = Rails.configuration.executehub[:jenkins]
  jenkins[:callback_shared_secret] = secret if jenkins
end