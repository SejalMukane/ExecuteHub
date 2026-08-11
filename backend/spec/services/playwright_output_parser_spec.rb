require "rails_helper"
require "tmpdir"

RSpec.describe PlaywrightOutputParser, type: :service do
  let(:fixture) { Rails.root.join("spec/fixtures/playwright/test-results.json") }
  let(:artifacts_dir) { Dir.mktmpdir("pw-artifacts") }
  let(:results_file) { File.join(artifacts_dir, "test-results.json") }

  before do
    FileUtils.cp(fixture, results_file)
    FileUtils.mkdir_p(File.join(artifacts_dir, "homepage-x"))
    FileUtils.mkdir_p(File.join(artifacts_dir, "login-x"))
    File.write(File.join(artifacts_dir, "homepage-x", "trace.zip"), "zip")
    File.write(File.join(artifacts_dir, "homepage-x", "video.webm"), "webm")
    File.write(File.join(artifacts_dir, "login-x", "test-failed-1.png"), "png")
  end

  after { FileUtils.rm_rf(artifacts_dir) }

  describe ".parse" do
    it "extracts passed/failed counts and duration from the report stats" do
      result = described_class.parse(results_file, artifacts_dir)

      expect(result[:passed]).to eq(2)
      expect(result[:failed]).to eq(1)
      expect(result[:duration_ms]).to eq(12346)
    end

    it "extracts individual test results" do
      result = described_class.parse(results_file, artifacts_dir)

      expect(result[:tests]).to eq(
        [
          {
            title: "homepage loads and exposes the expected title", file: "homepage.spec.ts",
            status: "passed", duration_ms: 930, retry: 0,
            error_message: nil, stack_trace: nil, started_at: nil
          },
          {
            title: "logs in with valid demo credentials", file: "login.spec.ts",
            status: "failed", duration_ms: 8300, retry: 0,
            error_message: nil, stack_trace: nil, started_at: nil
          }
        ]
      )
    end

    it "extracts retries, error message, stack trace and start time for retried failures" do
      payload = {
        "stats" => { "expected" => 0, "unexpected" => 1, "flaky" => 0, "skipped" => 0, "duration" => 5000 },
        "suites" => [
          {
            "title" => "login.spec.ts",
            "specs" => [
              {
                "title" => "logs in",
                "tests" => [
                  { "status" => "unexpected", "duration" => 1000.0, "startTime" => "2026-08-11T10:00:00.000Z" },
                  {
                    "status" => "unexpected", "duration" => 2000.0,
                    "startTime" => "2026-08-11T10:00:02.000Z",
                    "error" => {
                      "message" => "Error: expect(login).toBeVisible()\n\n    at /app/tests/login.spec.ts:12"
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
      File.write(results_file, JSON.generate(payload))

      test = described_class.parse(results_file, artifacts_dir)[:tests].first

      expect(test[:status]).to eq("failed")
      expect(test[:retry]).to eq(1)
      expect(test[:error_message]).to eq("Error: expect(login).toBeVisible()")
      expect(test[:stack_trace]).to include("login.spec.ts:12")
      expect(test[:started_at].utc.iso8601).to eq("2026-08-11T10:00:02Z")
    end

    it "maps Playwright flaky tests onto the flaky status" do
      payload = {
        "stats" => { "expected" => 0, "unexpected" => 0, "flaky" => 1, "skipped" => 0, "duration" => 3000 },
        "suites" => [
          { "title" => "suite.ts", "specs" => [{ "title" => "flaky test", "tests" => [{ "status" => "flaky", "duration" => 500.0 }] }] }
        ]
      }
      File.write(results_file, JSON.generate(payload))

      result = described_class.parse(results_file, artifacts_dir)

      expect(result[:flaky]).to eq(1)
      expect(result[:tests].first[:status]).to eq("flaky")
    end

    it "discovers screenshots, videos and traces in the output directory" do
      result = described_class.parse(results_file, artifacts_dir)

      expect(result[:screenshots].map { |p| p.basename.to_s }).to contain_exactly("test-failed-1.png")
      expect(result[:videos].map { |p| p.basename.to_s }).to contain_exactly("video.webm")
      expect(result[:traces].map { |p| p.basename.to_s }).to contain_exactly("trace.zip")
    end

    it "ignores non-artifact files such as the report itself" do
      result = described_class.parse(results_file, artifacts_dir)

      expect(result[:screenshots].map { |p| p.basename.to_s }).not_to include("test-results.json")
    end
  end
end
