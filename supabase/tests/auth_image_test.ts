import { strict as a } from "node:assert";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from "jose";
import { verifyFirebaseToken } from "../functions/proof-broker/firebase-auth.ts";
import { inspectImage } from "../functions/proof-broker/images.ts";
import { ApiError } from "../functions/proof-broker/types.ts";
const project = "fleetflow-dev-29e55";
const { privateKey, publicKey } = await generateKeyPair("RS256");
const key = await exportJWK(publicKey);
key.kid = "qa";
const keys = createLocalJWKSet({ keys: [key] });
async function token(
  options: { role?: string; aud?: string; issuer?: string; expires?: number } =
    {},
) {
  return new SignJWT({
    auth_time: Math.floor(Date.now() / 1000) - 10,
    role: options.role ?? "authenticated",
  }).setProtectedHeader({ alg: "RS256", kid: "qa" }).setSubject("driver")
    .setIssuer(options.issuer ?? `https://securetoken.google.com/${project}`)
    .setAudience(options.aud ?? project).setIssuedAt().setExpirationTime(
      options.expires ?? Math.floor(Date.now() / 1000) + 3600,
    ).sign(privateKey);
}
Deno.test("Firebase token verifier accepts only correct signed issuer/audience, claim, expiry and account status", async () => {
  a.equal(
    (await verifyFirebaseToken(
      await token(),
      project,
      async () => ({ validSince: 0 }),
      keys,
    )).uid,
    "driver",
  );
  for (
    const value of [
      await token({ role: "anon" }),
      await token({ aud: "another-project" }),
      await token({ issuer: "https://attacker" }),
      await token({ expires: 1 }),
      "not-a-token",
    ]
  ) {
    await a.rejects(
      () => verifyFirebaseToken(value, project, async () => ({}), keys),
      (e) => e instanceof ApiError && e.status === 401,
    );
  }
  for (
    const account of [null, { disabled: true }, {
      validSince: Math.floor(Date.now() / 1000),
    }]
  ) {
    await a.rejects(async () =>
      verifyFirebaseToken(await token(), project, async () => account, keys)
    );
  }
});
for (
  const [ext, mime] of [["jpg", "image/jpeg"], ["png", "image/png"], [
    "webp",
    "image/webp",
  ]]
) {
  Deno.test(`actual ${mime} decoder validates content and digest`, async () => {
    const bytes = await Deno.readFile(
      new URL(`./fixtures/proof.${ext}`, import.meta.url),
    );
    const info = await inspectImage(bytes);
    a.equal(info.mimeType, mime);
    a.equal(info.width, 2);
    a.equal(info.height, 2);
    a.match(info.sha256, /^[0-9a-f]{64}$/);
  });
}
Deno.test("empty, oversized, mislabeled, truncated and decompression-bomb images fail", async () => {
  for (
    const bytes of [
      new Uint8Array(),
      new Uint8Array(5000001),
      new TextEncoder().encode('<svg xmlns="http://www.w3.org/2000/svg"/>'),
      new Uint8Array([255, 216, 255, 1]),
    ]
  ) {
    await a.rejects(
      () => inspectImage(bytes),
      (e) => e instanceof ApiError && e.status === 422,
    );
  }
  const png = await Deno.readFile(
    new URL("./fixtures/proof.png", import.meta.url),
  );
  const bomb = png.slice();
  new DataView(bomb.buffer).setUint32(16, 100000);
  await a.rejects(() => inspectImage(bomb));
  const truncated = png.slice(0, 36);
  await a.rejects(() => inspectImage(truncated));
});
