import { defineConfig, devices } from "@playwright/test";
import { e2eEnv } from "./e2e/env";

const env = e2eEnv();
const port = Number(env.E2E_PORT);
// CI builds first and runs `next start`; locally set E2E_DEV=1 to use `next dev` instead.
const command = process.env.E2E_DEV === "1" ? `npx next dev -p ${port}` : `npx next start -p ${port}`;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : [["list"]],
  globalSetup: "./e2e/global-setup.ts",
  timeout: 60_000,
  use: {
    baseURL: env.PUBLIC_BASE_URL,
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command,
    url: `${env.PUBLIC_BASE_URL}/api/v1/health`,
    reuseExistingServer: false,
    timeout: 180_000,
    env: { ...env, NODE_ENV: process.env.E2E_DEV === "1" ? "development" : "production" },
  },
});
