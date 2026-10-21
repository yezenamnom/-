import { migrateDeploy, recreateDatabase } from "./db-admin";

export default async function setup() {
  const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  if (!/test/.test(new URL(url).pathname)) throw new Error("Refusing to run tests against a non-test database name");
  await recreateDatabase(url);
  migrateDeploy(url);
}
