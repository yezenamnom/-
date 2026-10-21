import { hash, verify } from "@node-rs/argon2";

// Argon2id (algorithm 2) — OWASP-recommended parameters (19 MiB, t=2, p=1).
const OPTIONS = { algorithm: 2, memoryCost: 19_456, timeCost: 2, parallelism: 1 } as const;

export const PASSWORD_MIN = 12;
export const PASSWORD_MAX = 256;

export function passwordPolicyProblem(pw: string): string | null {
  if (pw.length < PASSWORD_MIN) return `Password must be at least ${PASSWORD_MIN} characters`;
  if (pw.length > PASSWORD_MAX) return `Password must be at most ${PASSWORD_MAX} characters`;
  return null;
}

export async function hashPassword(pw: string): Promise<string> {
  return hash(pw, OPTIONS);
}

export async function verifyPassword(passwordHash: string, pw: string): Promise<boolean> {
  try {
    return await verify(passwordHash, pw);
  } catch {
    return false;
  }
}

let dummyHash: Promise<string> | null = null;

/** Burn comparable CPU time when the user does not exist (reduces user-enumeration timing signal). */
export async function verifyAgainstDummy(pw: string): Promise<false> {
  dummyHash ??= hashPassword("dummy-password-for-timing-equalisation");
  await verifyPassword(await dummyHash, pw);
  return false;
}
