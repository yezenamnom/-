import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { __velaPrisma?: PrismaClient };

export const prisma: PrismaClient =
  globalForPrisma.__velaPrisma ?? new PrismaClient({ log: ["error"] });

if (process.env.NODE_ENV !== "production") globalForPrisma.__velaPrisma = prisma;
