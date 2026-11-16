import {
  ImageMagick,
  initializeImageMagick,
  MagickFormat,
} from "@imagemagick/magick-wasm";
import { ApiError, type ImageInfo, MAX_BYTES, MAX_PIXELS } from "./types.ts";
let initialize: Promise<void> | undefined;
export function imageHeader(
  bytes: Uint8Array,
): { mimeType: string; width: number; height: number } {
  const fail = () => {
    throw new ApiError(
      422,
      "invalid_image",
      "A genuine, bounded JPEG, PNG or WebP image is required.",
    );
  };
  if (bytes.length < 12 || bytes.length > MAX_BYTES) return fail();
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let mimeType = "", width = 0, height = 0;
  if (
    bytes[0] === 137 && String.fromCharCode(...bytes.slice(1, 4)) === "PNG" &&
    bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10
  ) {
    if (
      bytes.length < 33 ||
      String.fromCharCode(...bytes.slice(12, 16)) !== "IHDR"
    ) return fail();
    mimeType = "image/png";
    width = v.getUint32(16);
    height = v.getUint32(20);
  } else if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) {
    mimeType = "image/jpeg";
    let offset = 2;
    while (offset + 4 < bytes.length) {
      if (bytes[offset++] !== 255) return fail();
      while (bytes[offset] === 255) offset++;
      const marker = bytes[offset++];
      if (marker === 217 || marker === 218) break;
      if (marker === 1 || (marker >= 208 && marker <= 215)) continue;
      if (offset + 2 > bytes.length) return fail();
      const size = v.getUint16(offset);
      if (size < 2 || offset + size > bytes.length) return fail();
      if (
        [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207]
          .includes(marker)
      ) {
        if (size < 7) return fail();
        height = v.getUint16(offset + 3);
        width = v.getUint16(offset + 5);
        break;
      }
      offset += size;
    }
  } else if (
    String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.slice(8, 12)) === "WEBP"
  ) {
    mimeType = "image/webp";
    if (v.getUint32(4, true) + 8 !== bytes.length) return fail();
    const chunk = String.fromCharCode(...bytes.slice(12, 16));
    if (chunk === "VP8X" && bytes.length >= 30) {
      if (bytes[20] & 2) return fail();
      width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
      height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
    } else if (chunk === "VP8L" && bytes.length >= 25 && bytes[20] === 47) {
      const bits = v.getUint32(21, true);
      width = (bits & 0x3fff) + 1;
      height = ((bits >>> 14) & 0x3fff) + 1;
    } else if (
      chunk === "VP8 " && bytes.length >= 30 && bytes[23] === 157 &&
      bytes[24] === 1 && bytes[25] === 42
    ) {
      width = v.getUint16(26, true) & 0x3fff;
      height = v.getUint16(28, true) & 0x3fff;
    } else return fail();
  } else return fail();
  if (
    width < 1 || height < 1 || width * height > MAX_PIXELS || width > 4096 ||
    height > 4096
  ) return fail();
  return { mimeType, width, height };
}
export async function inspectImage(bytes: Uint8Array): Promise<ImageInfo> {
  const header = imageHeader(bytes);
  initialize ??= (async () => {
    const wasm = await Deno.readFile(
      new URL(
        import.meta.resolve("npm:@imagemagick/magick-wasm@0.0.46/magick.wasm"),
      ),
    );
    await initializeImageMagick(wasm);
  })();
  await initialize;
  try {
    // Read performs a real decode, rather than trusting a filename, content type or magic bytes.
    ImageMagick.read(bytes, (image) => {
      const format = header.mimeType === "image/jpeg"
        ? MagickFormat.Jpeg
        : header.mimeType === "image/png"
        ? MagickFormat.Png
        : MagickFormat.WebP;
      if (
        image.format !== format || image.width !== header.width ||
        image.height !== header.height
      ) throw new Error("Decoded content mismatch");
      image.getPixels((pixels) =>
        pixels.toByteArray(0, 0, image.width, image.height, "RGBA")
      );
    });
  } catch {
    throw new ApiError(
      422,
      "invalid_image",
      "The uploaded file could not be decoded as a valid proof photograph.",
    );
  }
  const sha = Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer),
    ),
  ).map((v) => v.toString(16).padStart(2, "0")).join("");
  return { ...header, sizeBytes: bytes.length, sha256: sha };
}
