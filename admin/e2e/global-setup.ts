import { execFileSync } from "node:child_process";
import path from "node:path";
import { PrismaClient } from "@prisma/client";
import { hash } from "@node-rs/argon2";
import { migrateDeploy, recreateDatabase } from "../tests/db-admin";
import { e2eEnv, OWNER, READONLY } from "./env";

export default async function globalSetup() {
  const env = e2eEnv();
  if (!/e2e/.test(new URL(env.DATABASE_URL).pathname)) throw new Error("Refusing to use a non-e2e database");
  await recreateDatabase(env.DATABASE_URL);
  migrateDeploy(env.DATABASE_URL);
  const root = path.resolve(__dirname, "..");
  execFileSync(path.join(root, "node_modules/.bin/tsx"), ["prisma/seed.ts"], { cwd: root, env: { ...process.env, DATABASE_URL: env.DATABASE_URL }, stdio: "inherit" });
  const db = new PrismaClient({ datasourceUrl: env.DATABASE_URL });
  try {
    await db.adminUser.create({ data: { email: OWNER.email, role: "OWNER", passwordHash: await hash(OWNER.password) } });
    await db.adminUser.create({ data: { email: READONLY.email, role: "READONLY", passwordHash: await hash(READONLY.password) } });
  } finally {
    await db.$disconnect();
  }
}
