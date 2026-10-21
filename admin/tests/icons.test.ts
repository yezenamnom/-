import { describe, expect, it } from "vitest";
import sharp from "sharp";
import { processIcon, sniffImageType } from "@/lib/icons";

describe("icon processing", () => {
  it("re-encodes PNG/JPEG/WebP to PNG 128x128", async () => {
    for (const fmt of ["png", "jpeg", "webp"] as const) {
      const input = await sharp({ create: { width: 300, height: 200, channels: 3, background: "#ff0000" } })[fmt]().toBuffer();
      const r = await processIcon(input);
      expect(r.ok, fmt).toBe(true);
      if (!r.ok) continue;
      expect(sniffImageType(r.bytes)).toBe("image/png");
      const meta = await sharp(r.bytes).metadata();
      expect([meta.width, meta.height, meta.format]).toEqual([128, 128, "png"]);
    }
  });

  it("rejects SVG, other formats, oversize and garbage", async () => {
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
    expect((await processIcon(svg)).ok).toBe(false);
    const gif = await sharp({ create: { width: 10, height: 10, channels: 3, background: "#000" } }).gif().toBuffer();
    expect((await processIcon(gif)).ok).toBe(false);
    expect((await processIcon(Buffer.alloc(513 * 1024, 1))).ok).toBe(false);
    const fakePng = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from("not really a png")]);
    expect((await processIcon(fakePng)).ok).toBe(false);
    expect((await processIcon(Buffer.alloc(0))).ok).toBe(false);
  });
});
