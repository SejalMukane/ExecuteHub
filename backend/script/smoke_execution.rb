# Smoke test for Week 4 worker execution (Docker + Playwright + artifacts).
#
# Exercises the REAL pipeline end-to-end:
#   Job -> Docker container -> Playwright tests -> streamed logs ->
#   artifacts copied out -> parsed summary -> DB updates -> run progress.
#
# Requires: Docker running with the executehub-playwright image built.
#   docker build -f Dockerfile.playwright -t executehub-playwright:latest .
#
# Run via: ruby bin\rails runner script/smoke_execution.rb
user = User.find_by(email: "smoke-exec@test.dev") || User.create!(
  name: "Smoke Exec", email: "smoke-exec@test.dev",
  password: "password123", password_confirmation: "password123"
)
team = user.team || Team.create!(name: "Smoke Exec Team")
project = Project.create!(name: "Smoke Exec Project #{SecureRandom.hex(4)}", user: user, team: team)

run = TestRun.create!(project: project, branch: "main", commit_sha: "abc123", total_tests: 2)
job = run.jobs.create!(chunk_number: 1, test_count: 2, status: :queued)

puts "Executing Job ##{job.id} (2 tests) inside a Docker container..."

started = Time.current
WorkerExecutor.execute(job)
job.reload
run.reload

elapsed = (Time.current - started).round(1)
puts "Job ##{job.id} finished in #{elapsed}s"
puts "  status:     #{job.status}"
puts "  container:  #{job.container_id}"
puts "  passed:     #{job.passed_tests}"
puts "  failed:     #{job.failed_tests}"
puts "  duration_ms:#{job.duration_ms}"
puts "  logs:       #{job.execution_logs.count} lines"
puts "  artifacts:  #{job.artifacts.count} (#{job.artifacts.group(:artifact_type).count.inspect})"
puts "  run status: #{run.status} / #{run.progress_percentage}%"

raise "Expected completed job, got #{job.status}" unless job.completed?
raise "Expected 2 passed tests, got #{job.passed_tests}" unless job.passed_tests == 2
raise "Expected execution logs, got #{job.execution_logs.count}" unless job.execution_logs.count.positive?
raise "Expected videos + traces artifacts" unless job.artifacts.videos.any? && job.artifacts.traces.any?
raise "Expected finished_at to be set" if job.finished_at.nil?
raise "Expected 100% run progress" unless run.progress_percentage == 100.0
raise "Expected run to complete" unless run.completed?

puts "SMOKE EXECUTION PASSED"
