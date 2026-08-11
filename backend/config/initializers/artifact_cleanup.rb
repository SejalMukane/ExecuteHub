# Bootstraps the artifact retention sweep. ArtifactCleanupJob self-reschedules
# its next pass, but the FIRST pass needs an initial enqueue — kicked off here
# whenever a Sidekiq server boots. The Redis SETNX lock keeps concurrent
# processes from overlapping.
Sidekiq.configure_server do |config|
  config.on(:startup) do
    ArtifactCleanupJob.perform_async
  end
end
