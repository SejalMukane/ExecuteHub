# CiTriggerService is the idempotent entry point for CI-triggered test runs
# (default provider: Jenkins). It:
#
#   1. Finds-or-creates the Pipeline by its unique ci_key (e.g.
#      "jenkins:<job>:<build-number>") — a retried Jenkins trigger must never
#      create a second Pipeline.
#   2. Finds-or-creates the Build by the unique (project, job, build-number)
#      composite — retried triggers must never create a second Build.
#   3. Finds-or-creates the TestRun for that Pipeline. A brand new run is
#      scheduled via TestScheduler; an existing one is returned untouched so
#      duplicate triggers never double-schedule jobs.
#
# All lookups fall back on the DB unique constraints to stay correct under
# concurrent retries (find_or_create_by! + RecordNotUnique -> reload).
class CiTriggerService
  # Raised when the payload cannot be turned into a valid run (e.g. an unknown
  # test suite id, or total_tests resolving to zero).
  class InvalidParameters < StandardError; end

  # Immutable result of one trigger attempt.
  Result = Struct.new(:pipeline, :build, :test_run, :created, keyword_init: true)

  def self.call(project:, branch:, commit_sha:, jenkins_build_number:, job_name: nil,
                total_tests: nil, test_suite_id: nil)
    new(project: project, branch: branch, commit_sha: commit_sha,
        jenkins_build_number: jenkins_build_number, job_name: job_name,
        total_tests: total_tests, test_suite_id: test_suite_id).call
  end

  def initialize(project:, branch:, commit_sha:, jenkins_build_number:, job_name: nil,
                 total_tests: nil, test_suite_id: nil)
    @project = project
    @branch = branch.presence
    @commit_sha = commit_sha.presence
    @jenkins_build_number = jenkins_build_number
    @job_name = job_name.presence || JenkinsService.job_name
    @total_tests = total_tests
    @test_suite_id = test_suite_id
  end

  def call
    raise InvalidParameters, "branch is required" unless @branch
    raise InvalidParameters, "commit_sha is required" unless @commit_sha
    raise InvalidParameters, "jenkins_build_number is required" unless @jenkins_build_number.to_i > 0

    pipeline = find_or_create_pipeline
    build = find_or_create_build(pipeline)

    if pipeline.test_runs.exists?
      return Result.new(pipeline: pipeline, build: build,
                        test_run: pipeline.test_runs.order(:created_at).last,
                        created: false)
    end

    test_run = create_and_schedule_run(pipeline, build)

    Result.new(pipeline: pipeline, build: build, test_run: test_run, created: true)
  end

  private

  def ci_key
    @ci_key ||= "jenkins:#{@job_name}:#{@jenkins_build_number}"
  end

  # Unique on ci_key; a concurrent retry loses the insert race and reloads.
  def find_or_create_pipeline
    begin
      pipeline = Pipeline.find_or_create_by!(ci_key: ci_key) do |p|
        p.project = @project
        p.name = @job_name
        p.provider = :jenkins
        p.status = :running
        p.branch = @branch
        p.commit_sha = @commit_sha
        p.triggered_by = "jenkins"
      end
      created = pipeline.previously_new_record?
    rescue ActiveRecord::RecordNotUnique
      pipeline = Pipeline.find_by!(ci_key: ci_key)
      created = false
    end

    pipeline.update!(status: :running, branch: @branch, commit_sha: @commit_sha)
    DashboardEventService.pipeline_created(pipeline) if created
    DashboardEventService.pipeline_started(pipeline)
    pipeline
  end

  # Unique on (project_id, jenkins_job_name, jenkins_build_number).
  def find_or_create_build(pipeline)
    begin
      build = Build.find_or_create_by!(
        project: @project,
        jenkins_job_name: @job_name,
        jenkins_build_number: @jenkins_build_number
      ) do |b|
        b.pipeline = pipeline
        b.branch = @branch
        b.commit_sha = @commit_sha
      end
      created = build.previously_new_record?
    rescue ActiveRecord::RecordNotUnique
      build = Build.find_by!(
        project: @project,
        jenkins_job_name: @job_name,
        jenkins_build_number: @jenkins_build_number
      )
      created = false
    end

    build.update!(pipeline: pipeline) if build.pipeline_id != pipeline.id
    build.mark_running! unless build.terminal?
    DashboardEventService.build_started(build) if created
    build
  end

  def create_and_schedule_run(pipeline, build)
    test_run = pipeline.test_runs.create!(
      project: @project,
      branch: @branch,
      commit_sha: @commit_sha,
      total_tests: resolve_total_tests,
      status: :queued
    )
    TestScheduler.call(test_run)
    build.update!(test_run: test_run)
    DashboardEventService.test_run_started_for_ci(test_run)
    test_run
  end

  # Precedence: explicit total_tests > selected suite's count > config default.
  def resolve_total_tests
    return @total_tests.to_i if @total_tests.to_i > 0

    if @test_suite_id.present?
      suite = TestSuite.find_by(id: @test_suite_id)
      raise InvalidParameters, "test_suite_id not found" unless suite
      return suite.total_tests
    end

    default = Rails.configuration.executehub[:ci].to_h.with_indifferent_access[:default_total_tests].to_i
    default = 20 if default <= 0
    default
  end
end
