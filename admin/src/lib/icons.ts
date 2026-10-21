/**
 * Icon upload processing. Only PNG/JPEG/WebP uploads are accepted (detected by magic bytes,
 * not by the client-declared type); SVG and everything else is rejected. The image is decoded
 * and re-encoded with sharp to a 128x128 PNG, which strips metadata and any embedded payloads.
 * There is deliberately no "fetch icon from URL" feature (no SSRF surface).
 */
import sharp from "sharp";
import { sha256Hex } from "./blocklist";

export const ICON_MAX_BYTES = 512 * 1024;
export const ICON_SIZE = 128;

export type SniffedType = "image/png" | "image/jpeg" | "image/webp";

export function sniffImageType(buf: Buffer): SniffedType | null {
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "image/png";
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return "image/jpeg";
  if (buf.length >= 12 && buf.toString("ascii", 0, 4) === "RIFF" && buf.toString("ascii", 8, 12) === "WEBP") return "image/webp";
  return null;
}

export type IconResult =
  | { ok: true; bytes: Buffer; mime: "image/png"; sha256: string; width: number; height: number }
  | { ok: false; error: string };

export async function processIcon(input: Buffer): Promise<IconResult> {
  if (input.length === 0) return { ok: false, error: "Empty file" };
  if (input.length > ICON_MAX_BYTES) return { ok: false, error: "File larger than 512 KB" };
  const type = sniffImageType(input);
  if (!type) return { ok: false, error: "Only PNG, JPEG or WebP images are accepted" };
  try {
    const img = sharp(input, { failOn: "error", limitInputPixels: 4096 * 4096, animated: false });
    const meta = await img.metadata();
    const fmt = meta.format;
    if (fmt !== "png" && fmt !== "jpeg" && fmt !== "webp") return { ok: false, error: "Only PNG, JPEG or WebP images are accepted" };
    const bytes = await img
      .rotate()
      .resize(ICON_SIZE, ICON_SIZE, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
      .png({ compressionLevel: 9 })
      .toBuffer();
    return { ok: true, bytes, mime: "image/png", sha256: sha256Hex(bytes), width: ICON_SIZE, height: ICON_SIZE };
  } catch {
    return { ok: false, error: "Image could not be decoded" };
  }
}
