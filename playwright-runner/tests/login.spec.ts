import { test, expect } from "@playwright/test";

// Demo login page (https://the-internet.herokuapp.com/login) accepts the
// well-known demo credentials and responds with a visible flash message.
test("logs in with valid demo credentials", async ({ page }) => {
  await page.goto("https://the-internet.herokuapp.com/login");

  await page.locator("#username").fill("tomsmith");
  await page.locator("#password").fill("SuperSecretPassword!");
  await page.locator("button[type=submit]").click();

  await expect(page.locator("#flash.success")).toBeVisible({ timeout: 15_000 });
  await expect(page).toHaveURL(/\/secure/);
});
