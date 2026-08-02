# WorkerHeartbeat is the source of truth for the health of a logical worker in
# the pool (Worker-01, Worker-02, ...). Workers report a heartbeat every
# heartbeat_interval_seconds (default 5s); a worker whose heartbeat is older
# than heartbeat_stale_seconds (default 15s) is considered Offline.
#
# Statuses:
#   idle    - registered and healthy, not currently executing a job
#   busy    - executing a job (current_job_id points at it)
#   offline - heartbeat too old (crashed / disconnected / never started)
class WorkerHeartbeat < ApplicationRecord
  belongs_to :current_job, class_name: "Job", optional: true

  enum :status, {
    idle: "idle",
    busy: "busy",
    offline: "offline"
  }, default: :idle

  validates :worker_name, presence: true, uniqueness: true,
            format: { with: /\AWorker-\d+\z/, message: "must look like Worker-01" }
  validates :cpu_usage, :memory_usage,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :execution_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where.not(status: :offline) }
  scope :available, -> { where(status: :idle) }
  scope :busy, -> { where(status: :busy) }
  scope :offline, -> { where(status: :offline) }

  # Seconds before a worker is declared offline (config-driven default 15).
  def self.stale_after
    Rails.configuration.executehub.fetch("heartbeat_stale_seconds", 15).to_i
  end

  # Workers whose heartbeat is older than the stale threshold (or never seen).
  scope :stale, -> { where("last_seen_at IS NULL OR last_seen_at < ?", stale_after.seconds.ago) }

  def mark_busy!(job)
    update!(status: :busy, current_job: job, last_seen_at: Time.current)
  end

  def mark_idle!
    update!(status: :idle, current_job: nil, last_seen_at: Time.current)
  end

  def mark_offline!
    update!(status: :offline)
  end

  # True when this worker's heartbeat is fresh enough to be considered alive.
  def healthy?
    status != "offline" && last_seen_at&.>(self.class.stale_after.seconds.ago)
  end

  def offline?
    status == "offline"
  end
end
