/**
 * Create the first OWNER admin.
 *   npm run admin:create-owner -- --email you@example.com [--force]
 * Password: read from ADMIN_PASSWORD (for CI/automation) or prompted on the terminal (hidden).
 * Refuses when an OWNER already exists, unless --force.
 */
import { createInterface } from "node:readline";
import { Writable } from "node:stream";
import { PrismaClient } from "@prisma/client";
import { z } from "zod";
import { hashPassword, passwordPolicyProblem } from "../src/lib/auth/password";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  if (i >= 0) return process.argv[i + 1];
  const eq = process.argv.find((a) => a.startsWith(`${name}=`));
  return eq?.slice(name.length + 1);
}

async function promptHidden(question: string): Promise<string> {
  if (!process.stdin.isTTY) {
    // Non-interactive: read one line from stdin.
    const rl = createInterface({ input: process.stdin });
    for await (const line of rl) {
      rl.close();
      return line;
    }
    return "";
  }
  let muted = false;
  const out = new Writable({
    write(chunk, _enc, cb) {
      if (!muted) process.stdout.write(chunk);
      cb();
    },
  });
  const rl = createInterface({ input: process.stdin, output: out, terminal: true });
  return new Promise((resolve) => {
    process.stdout.write(question);
    muted = true;
    rl.question("", (answer) => {
      muted = false;
      process.stdout.write("\n");
      rl.close();
      resolve(answer);
    });
  });
}

async function main() {
  const emailRaw = arg("--email");
  const force = process.argv.includes("--force");
  const email = z.string().trim().toLowerCase().email().max(254).safeParse(emailRaw ?? "");
  if (!email.success) {
    console.error("Usage: npm run admin:create-owner -- --email you@example.com [--force]");
    process.exit(2);
  }
  const prisma = new PrismaClient();
  try {
    const owners = await prisma.adminUser.count({ where: { role: "OWNER" } });
    if (owners > 0 && !force) {
      console.error("An OWNER already exists. Refusing (use --force to add/replace an owner anyway).");
      process.exit(1);
    }
    const existing = await prisma.adminUser.findUnique({ where: { email: email.data } });
    if (existing && !force) {
      console.error("A user with this email already exists. Use --force to promote it to OWNER and reset its password.");
      process.exit(1);
    }
    let password = process.env.ADMIN_PASSWORD ?? "";
    if (!password) {
      password = await promptHidden("Password (min 12 chars): ");
      const again = process.stdin.isTTY ? await promptHidden("Repeat password: ") : password;
      if (again !== password) {
        console.error("Passwords do not match.");
        process.exit(1);
      }
    }
    const problem = passwordPolicyProblem(password);
    if (problem) {
      console.error(problem);
      process.exit(1);
    }
    const passwordHash = await hashPassword(password);
    const user = await prisma.adminUser.upsert({
      where: { email: email.data },
      create: { email: email.data, passwordHash, role: "OWNER" },
      update: { passwordHash, role: "OWNER", disabled: false, failedLoginCount: 0, lockedUntil: null },
    });
    await prisma.session.deleteMany({ where: { userId: user.id } });
    await prisma.auditLog.create({ data: { actorId: null, action: "user.create_owner_cli", entity: "AdminUser", entityId: user.id, after: { email: user.email, role: user.role } } });
    console.log(`OWNER ready: ${user.email}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
