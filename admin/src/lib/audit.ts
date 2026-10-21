import type { Prisma, PrismaClient } from "@prisma/client";
import { prisma } from "./db";

type Tx = Prisma.TransactionClient | PrismaClient;

export type AuditEntry = {
  actorId: string | null;
  action: string;
  entity: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
  ip?: string | null;
};

const toJson = (v: unknown): Prisma.InputJsonValue | undefined =>
  v === undefined || v === null ? undefined : (JSON.parse(JSON.stringify(v)) as Prisma.InputJsonValue);

export async function audit(entry: AuditEntry, tx: Tx = prisma): Promise<void> {
  await tx.auditLog.create({
    data: {
      actorId: entry.actorId,
      action: entry.action,
      entity: entry.entity,
      entityId: entry.entityId ?? null,
      before: toJson(entry.before),
      after: toJson(entry.after),
      ip: entry.ip ?? null,
    },
  });
}
