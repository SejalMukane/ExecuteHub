require "json"

# PlaywrightOutputParser turns the JSON report produced by Playwright's "json"
# reporter into a machine-readable execution summary:
#
#   {
#     passed:      2,
#     failed:      1,
#     duration_ms: 12346,
#     tests:       [ { title:, file:, status:, duration_ms: } ],
#     screenshots: [ <absolute Pathname>, ... ],   # *.png
#     videos:      [ <absolute Pathname>, ... ],   # *.webm
#     traces:      [ <absolute Pathname>, ... ]    # *.zip (trace.zip)
#   }
#
# The results file and the artifact files are expected to live in the same
# directory (the per-job output copied out of the container).
class PlaywrightOutputParser
  def self.parse(results_file, artifacts_dir)
    new(results_file, artifacts_dir).parse
  end

  def initialize(results_file, artifacts_dir)
    @results_file = Pathname.new(results_file)
    @artifacts_dir = Pathname.new(artifacts_dir)
  end

  def parse
    data = JSON.parse(@results_file.read)

    {
      passed: stats(data, "expected"),
      failed: stats(data, "unexpected"),
      duration_ms: stats(data, "duration").to_f.round,
      tests: extract_tests(data),
      screenshots: scan_files("png"),
      videos: scan_files("webm"),
      traces: scan_files("zip")
    }
  end

  private

  def stats(data, key)
    data.dig("stats", key).to_i
  end

  # Flattens suites -> specs -> tests into a list of individual test outcomes.
  def extract_tests(data)
    Array(data["suites"]).flat_map do |suite|
      Array(suite["specs"]).map do |spec|
        test = Array(spec["tests"]).first || {}
        {
          title: spec["title"],
          file: suite["title"],
          status: test_status(test["status"]),
          duration_ms: test["duration"].to_f.round
        }
      end
    end
  end

  # Maps Playwright's internal statuses onto our vocabulary.
  def test_status(status)
    case status
    when "unexpected", "flaky" then "failed"
    when "skipped" then "skipped"
    else "passed"
    end
  end

  # Recursively finds artifacts of the given extension under the output dir.
  def scan_files(extension)
    Dir.glob(@artifacts_dir.join("**", "*.#{extension}")).map { |path| Pathname.new(path) }.sort
  end
end
