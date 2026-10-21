import { defineConfig } from "vitest/config";
import path from "node:path";

const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? "postgresql://vela:vela_dev_pw@localhost:54329/vela_test?schema=public";

// Make the test DB visible to globalSetup (runs in the main process, outside `test.env`).
process.env.TEST_DATABASE_URL = TEST_DATABASE_URL;

export default defineConfig({
  resolve: { alias: { "@": path.resolve(__dirname, "src") } },
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    globalSetup: ["tests/global-setup.ts"],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 120_000,
    env: {
      DATABASE_URL: TEST_DATABASE_URL,
      TEST_DATABASE_URL,
      APP_ENV: "development",
      REPORT_IP_SALT: "test-salt-not-a-secret-0123456789",
      PUBLIC_BASE_URL: "http://admin.test",
      CONFIG_SIGNING_KEY_ID: "k1",
    },
  },
});
