require "json"

# PlaywrightOutputParser turns the JSON report produced by Playwright's "json"
# reporter into a machine-readable execution summary:
#
#   {
#     passed:      2,
#     failed:      1,
#     flaky:       0,
#     skipped:     0,
#     duration_ms: 12346,
#     tests:       [ { title:, file:, status:, duration_ms:, retry:,
#                       error_message:, stack_trace:, started_at: } ],
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
      flaky: stats(data, "flaky"),
      skipped: stats(data, "skipped"),
      duration_ms: duration_ms(data),
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

  def duration_ms(data)
    data.dig("stats", "duration").to_f.round
  end

  # Flattens suites -> specs -> tests into a list of individual test outcomes.
  # Playwright stores one entry per attempt under spec["tests"]; the last
  # attempt carries the final outcome and, for failures, the error to debug.
  def extract_tests(data)
    Array(data["suites"]).flat_map do |suite|
      Array(suite["specs"]).map do |spec|
        attempts = Array(spec["tests"])
        final = attempts.last || {}
        {
          title: spec["title"],
          file: suite["title"],
          status: test_status(final["status"]),
          duration_ms: final["duration"].to_f.round,
          retry: [attempts.size - 1, 0].max,
          error_message: error_message(final["error"]),
          stack_trace: stack_trace(final["error"]),
          started_at: parse_started_at(final["startTime"])
        }
      end
    end
  end

  # Maps Playwright's internal statuses onto our vocabulary.
  def test_status(status)
    case status
    when "unexpected" then "failed"
    when "flaky" then "flaky"
    when "skipped" then "skipped"
    else "passed"
    end
  end

  # First line of the error message — a concise headline for the UI.
  def error_message(error)
    return unless error

    error["message"].to_s.lines.first&.strip
  end

  # Full error message (Playwright embeds the stack in it) for the detail view.
  def stack_trace(error)
    return unless error

    error["message"].to_s
  end

  def parse_started_at(value)
    Time.iso8601(value)
  rescue ArgumentError, TypeError
    nil
  end

  # Recursively finds artifacts of the given extension under the output dir.
  def scan_files(extension)
    Dir.glob(@artifacts_dir.join("**", "*.#{extension}")).map { |path| Pathname.new(path) }.sort
  end
end
