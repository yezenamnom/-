import { adminRoute } from "@/lib/admin-route";
import { prisma } from "@/lib/db";
import { audit } from "@/lib/audit";
import { HttpError, json } from "@/lib/http";
import { ICON_MAX_BYTES, processIcon } from "@/lib/icons";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** multipart/form-data with a single `file` field (PNG/JPEG/WebP, ≤ 512 KB). Stored re-encoded as PNG 128x128. */
export const POST = adminRoute("ADMIN", async ({ req, user, ip }) => {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > ICON_MAX_BYTES + 16 * 1024) throw new HttpError(413, "payload_too_large", "File larger than 512 KB");
  if (!(req.headers.get("content-type") ?? "").toLowerCase().startsWith("multipart/form-data")) {
    throw new HttpError(415, "unsupported_media_type", "Expected multipart/form-data");
  }
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    throw new HttpError(400, "invalid_form");
  }
  const file = form.get("file");
  if (!(file instanceof Blob)) throw new HttpError(400, "validation_failed", "Missing file");
  if (file.size > ICON_MAX_BYTES) throw new HttpError(413, "payload_too_large", "File larger than 512 KB");
  const result = await processIcon(Buffer.from(await file.arrayBuffer()));
  if (!result.ok) throw new HttpError(400, "invalid_image", result.error);
  const asset = await prisma.asset.upsert({
    where: { sha256: result.sha256 },
    create: { bytes: new Uint8Array(result.bytes), mime: result.mime, sha256: result.sha256, width: result.width, height: result.height },
    update: {},
    select: { id: true, sha256: true, width: true, height: true, mime: true },
  });
  await audit({ actorId: user.id, action: "asset.upload", entity: "Asset", entityId: asset.id, after: asset, ip });
  return json({ ...asset, url: `/api/v1/assets/${asset.id}` }, 201);
});
