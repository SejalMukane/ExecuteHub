# Bootstraps the worker-pool heartbeat driver. HeartbeatWorker self-reschedules
# its next pass via perform_in, but nothing would enqueue the FIRST pass on its
# own — so we kick it off whenever a Sidekiq server boots. The Redis SETNX lock
# inside HeartbeatWorker keeps concurrent passes from overlapping even if
# multiple Sidekiq processes boot at once.
Sidekiq.configure_server do |config|
  config.on(:startup) do
    HeartbeatWorker.perform_async
  end
end
