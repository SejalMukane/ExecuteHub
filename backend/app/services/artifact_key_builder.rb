# ArtifactKeyBuilder produces the predictable S3 key layout for every artifact
# (Part 3). Keys are never random flat filenames — they follow the hierarchy
# so S3 buckets (and humans) can browse by project / run / job / type:
#
#   executehub/
#     projects/project_12/test_runs/run_42/jobs/job_101/
#       screenshots/<timestamp>_<hex>_login.png
#       videos/...
#       traces/...
#       logs/...
#       reports/...
#
# The timestamp + random hex prefix prevents filename collisions while keeping
# the original filename readable at the end of the key.
class ArtifactKeyBuilder
  ROOT = "executehub".freeze

  class << self
    def build(job:, artifact_type:, original_name:)
      new(job, artifact_type, original_name).build
    end
  end

  def initialize(job, artifact_type, original_name)
    @job = job
    @artifact_type = artifact_type
    @original_name = original_name.to_s
  end

  def build
    [
      ROOT,
      "projects",
      "project_#{project_id}",
      "test_runs",
      "run_#{@job.test_run_id}",
      "jobs",
      "job_#{@job.id}",
      "#{@artifact_type.pluralize}",
      unique_file_name
    ].join("/")
  end

  private

  def project_id
    @job.test_run&.project_id || 0
  end

  # Timestamp + hex guarantees uniqueness even when two identical filenames
  # collide; the original basename is kept for human-readable debugging.
  def unique_file_name
    "#{Time.current.strftime("%Y%m%d_%H%M%S")}_#{SecureRandom.hex(4)}_#{sanitized_name}"
  end

  def sanitized_name
    File.basename(@original_name).presence || "artifact"
  end
end
