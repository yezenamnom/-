import { execFileSync } from "node:child_process";
import path from "node:path";
import { PrismaClient } from "@prisma/client";

/** Connection to the server's maintenance DB (`postgres`) derived from a database URL. */
export function maintenanceUrl(dbUrl: string): string {
  const u = new URL(dbUrl);
  u.pathname = "/postgres";
  u.search = "";
  return u.toString();
}

export function dbName(dbUrl: string): string {
  return new URL(dbUrl).pathname.replace(/^\//, "");
}

export async function recreateDatabase(dbUrl: string): Promise<void> {
  const name = dbName(dbUrl);
  if (!/^[a-z0-9_]+$/.test(name)) throw new Error("unsafe test database name");
  const admin = new PrismaClient({ datasourceUrl: maintenanceUrl(dbUrl) });
  try {
    await admin.$executeRawUnsafe(`DROP DATABASE IF EXISTS "${name}" WITH (FORCE)`);
    await admin.$executeRawUnsafe(`CREATE DATABASE "${name}"`);
  } finally {
    await admin.$disconnect();
  }
}

export async function dropDatabase(dbUrl: string): Promise<void> {
  const name = dbName(dbUrl);
  if (!/^[a-z0-9_]+$/.test(name)) throw new Error("unsafe test database name");
  const admin = new PrismaClient({ datasourceUrl: maintenanceUrl(dbUrl) });
  try {
    await admin.$executeRawUnsafe(`DROP DATABASE IF EXISTS "${name}" WITH (FORCE)`);
  } finally {
    await admin.$disconnect();
  }
}

export function migrateDeploy(dbUrl: string): string {
  const root = path.resolve(__dirname, "..");
  return execFileSync(path.join(root, "node_modules/.bin/prisma"), ["migrate", "deploy"], {
    cwd: root,
    env: { ...process.env, DATABASE_URL: dbUrl },
    encoding: "utf8",
  });
}
