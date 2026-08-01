# Smoke test for Week 3 orchestration (scheduler -> Redis -> worker -> progress).
# Run via: ruby bin\rails runner script/smoke_orchestration.rb
require "sidekiq/api"

user = User.find_by(email: "smoke@test.dev") || User.create!(
  name: "Smoke", email: "smoke@test.dev",
  password: "password123", password_confirmation: "password123"
)
team = user.team || Team.create!(name: "Smoke Team")
project = Project.create!(name: "Smoke Project #{SecureRandom.hex(4)}", user: user, team: team)

queue = Sidekiq::Queue.new("test_execution")
queue.clear

run = TestRun.create!(project: project, branch: "main", commit_sha: "abc123", total_tests: 100)
TestScheduler.call(run)
run.reload

raise "Expected 5 jobs" unless run.total_jobs == 5
raise "Expected status queued" unless run.status == "queued"
raise "Expected 5 queued jobs on run" unless run.queued_jobs == 5
raise "Expected 5 jobs in Redis queue" unless queue.size == 5

puts "Scheduled: status=#{run.status} total_jobs=#{run.total_jobs} redis_queue_size=#{queue.size}"

# Simulate a Sidekiq process picking up each job.
run.jobs.order(:chunk_number).each do |job|
  raise "Expected queued job" unless job.queued?
  TestExecutionWorker.new.perform(job.id)
end
run.reload

raise "Expected 5 completed" unless run.completed_jobs == 5
raise "Expected status completed" unless run.status == "completed"
raise "Expected 100% progress" unless run.progress_percentage == 100.0
raise "Expected finished_at set" if run.finished_at.nil?

puts "Processed: status=#{run.status} completed=#{run.completed_jobs} progress=#{run.progress_percentage}%"

queue.clear
puts "SMOKE TEST PASSED"
