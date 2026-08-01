import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright configuration for the ExecuteHub demo runner.
 *
 * - `trace: "on"`          -> a trace.zip is produced for every test so
 *                              ExecuteHub can expose them as downloadable artifacts.
 * - `video: "on"`          -> a video (.webm) is recorded for every test.
 * - `screenshot: "only-on-failure"` -> screenshots are captured when a test fails.
 * - JSON reporter writes machine-readable results into
 *   `artifacts/test-results.json` so WorkerExecutor can parse the run summary.
 */
export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ["list"],
    ["json", { outputFile: "artifacts/test-results.json" }]
  ],
  use: {
    baseURL: "https://example.com",
    trace: "on",
    video: "on",
    screenshot: "only-on-failure"
  },
  outputDir: "artifacts",
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ]
});
