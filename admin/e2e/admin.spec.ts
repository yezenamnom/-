import { expect, test, type Page } from "@playwright/test";
import { createPublicKey, verify } from "node:crypto";
import { e2eKeys, OWNER, READONLY } from "./env";

test.describe.configure({ mode: "serial" });

async function login(page: Page, who: { email: string; password: string }) {
  await page.goto("/login");
  await page.getByLabel("Email").fill(who.email);
  await page.getByLabel("Password").fill(who.password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
}

test("unauthenticated users are sent to /login; wrong password shows a generic error", async ({ page }) => {
  await page.goto("/shortcuts");
  await expect(page).toHaveURL(/\/login$/);
  await page.getByLabel("Email").fill(OWNER.email);
  await page.getByLabel("Password").fill("definitely-wrong-password");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByTestId("msg-error")).toContainText("Sign-in failed");
  await expect(page).toHaveURL(/\/login$/);
});

test("security headers are present on pages", async ({ page }) => {
  const res = await page.goto("/login");
  const h = res!.headers();
  expect(h["x-frame-options"]).toBe("DENY");
  expect(h["x-content-type-options"]).toBe("nosniff");
  expect(h["referrer-policy"]).toBe("no-referrer");
  expect(h["content-security-policy"]).toMatch(/script-src 'self' 'nonce-[^']+' 'strict-dynamic'/);
  expect(h["content-security-policy"]).not.toMatch(/script-src[^;]*'unsafe-inline'/);
});

test("owner logs in, sees status, creates a shortcut and publishes a verifiable config", async ({ page, request }) => {
  await login(page, OWNER);
  await expect(page.getByTestId("db-status")).toHaveText("OK");
  await expect(page.getByTestId("signing-key")).toHaveText("Yes");
  await expect(page.getByTestId("admob")).toHaveText("Not connected");
  await expect(page.getByTestId("current-version")).toHaveText("Nothing published yet");

  await page.getByRole("link", { name: "Shortcuts" }).click();
  await expect(page.getByTestId("shortcut-youtube")).toBeVisible();
  await page.getByTestId("new-shortcut").click();
  const form = page.getByTestId("shortcut-form");
  await form.getByLabel("Key (id)").fill("vimeo");
  await form.getByLabel("URL (https only)").fill("https://vimeo.com/");
  await form.getByLabel("Title (en)").fill("Vimeo");
  await form.getByLabel("Title (ar)").fill("فيميو");
  await form.getByLabel("Title (de)").fill("Vimeo");
  await form.getByLabel("Built-in icon").selectOption("vimeo");
  await form.getByRole("button", { name: "Save" }).click();
  await expect(page.getByTestId("shortcut-vimeo")).toBeVisible();

  // Server-side validation surfaces in the UI: http URL is rejected.
  await page.getByTestId("new-shortcut").click();
  await form.getByLabel("Key (id)").fill("insecure");
  await form.getByLabel("URL (https only)").fill("http://example.com/");
  await form.getByLabel("Title (en)").fill("Insecure");
  await form.getByRole("button", { name: "Save" }).click();
  await expect(page.getByTestId("msg-error")).toContainText("https");
  await form.getByRole("button", { name: "Cancel" }).click();

  await page.getByRole("link", { name: "Publish" }).click();
  await expect(page.getByTestId("draft-valid")).toBeVisible();
  await expect(page.getByTestId("draft-json")).toContainText('"id": "vimeo"');
  await page.getByLabel("Release note").fill("E2E first release");
  await page.getByTestId("publish-button").click();
  await expect(page.getByTestId("msg-success")).toContainText("Published version v1");

  const res = await request.get("/api/v1/config?platform=android&appVersion=1.0.0");
  expect(res.status()).toBe(200);
  const env = (await res.json()) as { keyId: string; payload: string; signature: string };
  expect(env.keyId).toBe("k1");
  const pub = createPublicKey({ key: { kty: "OKP", crv: "Ed25519", x: e2eKeys().publicKeyRawB64url }, format: "jwk" });
  const bytes = Buffer.from(env.payload, "base64url");
  expect(verify(null, bytes, pub, Buffer.from(env.signature, "base64url"))).toBe(true);
  const tampered = Buffer.from(bytes.toString("utf8").replace("vimeo", "evil0"));
  expect(verify(null, tampered, pub, Buffer.from(env.signature, "base64url"))).toBe(false);
  const payload = JSON.parse(bytes.toString("utf8"));
  expect(payload.configVersion).toBe(1);
  expect(payload.shortcuts.map((s: { id: string }) => s.id)).toEqual(["youtube", "twitch", "tiktok", "rumble", "vimeo"]);
  expect(payload.ads.placements[0].adUnitIdAndroid).toBe("ca-app-pub-3940256099942544/9214589741");

  await page.getByRole("link", { name: "Dashboard" }).click();
  await expect(page.getByTestId("current-version")).toHaveText("v1");
});

test("readonly user cannot see or perform edits", async ({ page }) => {
  await login(page, READONLY);
  await expect(page.getByTestId("current-role")).toHaveText("READONLY");
  await expect(page.getByRole("link", { name: "Users" })).toHaveCount(0);

  await page.getByRole("link", { name: "Shortcuts" }).click();
  await expect(page.getByTestId("shortcut-youtube")).toBeVisible();
  await expect(page.getByText("Read-only access")).toBeVisible();
  await expect(page.getByTestId("new-shortcut")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Edit" })).toHaveCount(0);

  await page.getByRole("link", { name: "Publish" }).click();
  await expect(page.getByTestId("publish-button")).toHaveCount(0);

  // Even a hand-crafted API call with a valid session + CSRF token is refused server-side.
  const status = await page.evaluate(async () => {
    const me = await (await fetch("/api/admin/auth/me")).json();
    const r = await fetch("/api/admin/publish", {
      method: "POST",
      headers: { "content-type": "application/json", "x-csrf-token": me.csrfToken },
      body: JSON.stringify({ note: "sneaky" }),
    });
    return r.status;
  });
  expect(status).toBe(403);

  await page.goto("/users");
  await expect(page).toHaveURL(/\/\?denied=1$/);
  await expect(page.getByText("You do not have permission")).toBeVisible();
});

test("logout ends the session", async ({ page }) => {
  await login(page, OWNER);
  await page.getByTestId("logout").click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/");
  await expect(page).toHaveURL(/\/login$/);
  const me = await page.request.get("/api/admin/auth/me");
  expect(me.status()).toBe(401);
});
