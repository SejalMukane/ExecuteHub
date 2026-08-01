import { test, expect } from "@playwright/test";

test("homepage loads and exposes the expected title", async ({ page }) => {
  await page.goto("https://example.com");

  await expect(page).toHaveTitle(/Example Domain/);
  await expect(page.locator("h1")).toHaveText("Example Domain");
  await expect(page.locator("p").first()).toContainText("This domain is for use in");
});
