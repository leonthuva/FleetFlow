import { strict as a } from "node:assert";
import { ProofBroker } from "../functions/proof-broker/broker.ts";
import { inspectImage } from "../functions/proof-broker/images.ts";
import { ApiError, type Data } from "../functions/proof-broker/types.ts";
import { MemoryDatabase, MemoryStorage } from "./fakes.ts";
const id = "12345678-1234-4234-8234-123456789abc";
const otherId = "22345678-1234-4234-8234-123456789abc";
const bytes = await Deno.readFile(
  new URL("./fixtures/proof.png", import.meta.url),
);
const image = await inspectImage(bytes);
function setup() {
  let time = new Date("2026-11-16T12:00:00Z");
  const now = () => time;
  const db = new MemoryDatabase(now), storage = new MemoryStorage();
  db.docs.set("users/driver", { role: "driver" });
  db.docs.set("users/other", { role: "driver" });
  db.docs.set("users/manager", { role: "admin" });
  db.docs.set("deliveries/D1", { driverId: "driver", status: "arrived" });
  db.docs.set("notificationTargets/managers", { uids: ["manager", "other"] });
  const broker = new ProofBroker({ db, storage, inspectImage, now });
  const call = (body: Data, uid = "driver") => broker.execute({ uid }, body);
  const begin = (extra: Data = {}) =>
    call({
      action: "begin",
      deliveryId: "D1",
      attemptId: id,
      mimeType: image.mimeType,
      sizeBytes: image.sizeBytes,
      sha256: image.sha256,
      ...extra,
    });
  const upload = async () => {
    const grant = await begin();
    storage.objects.set(String(grant.path), {
      bytes,
      mimeType: image.mimeType,
    });
    return grant;
  };
  return {
    db,
    storage,
    broker,
    call,
    begin,
    upload,
    advance: () => {
      time = new Date(time.getTime() + 16 * 60_000);
    },
  };
}
const fails = (fn: () => Promise<unknown>, status: number) =>
  a.rejects(
    fn,
    (error: unknown) => error instanceof ApiError && error.status === status,
  );
Deno.test("cross-driver, non-driver, missing assignment and invalid stages cannot acquire grants", async () => {
  const t = setup();
  await fails(
    () =>
      t.call({
        action: "begin",
        deliveryId: "D1",
        attemptId: id,
        mimeType: "image/png",
        sizeBytes: image.sizeBytes,
        sha256: image.sha256,
      }, "other"),
    403,
  );
  await fails(
    () =>
      t.call({
        action: "begin",
        deliveryId: "D1",
        attemptId: id,
        mimeType: "image/png",
        sizeBytes: image.sizeBytes,
        sha256: image.sha256,
      }, "manager"),
    403,
  );
  t.db.docs.get("deliveries/D1")!.status = "in_transit";
  await fails(() => t.begin(), 409);
  a.equal(t.storage.grants.size, 0);
});
Deno.test("valid begin is idempotent and repairs grant failure without a second intent", async () => {
  const t = setup();
  t.storage.failGrant = true;
  await fails(() => t.begin(), 503);
  const first = await t.begin();
  const second = await t.begin({ attemptId: otherId });
  a.equal(first.path, `driver/D1/${id}.png`);
  a.equal(second.attemptId, id);
  a.equal(t.storage.grants.size, 1);
});
Deno.test("invalid size, SHA, bucket/path inputs and conflicting attempts are rejected", async () => {
  const t = setup();
  await fails(() => t.begin({ sizeBytes: 5000001 }), 400);
  await fails(() => t.begin({ sha256: "fake" }), 400);
  await fails(() => t.begin({ deliveryId: "../D1" }), 400);
  const g = await t.begin({ bucket: "public", path: "other/D1/forged.png" });
  a.equal(g.bucket, "delivery-proofs");
  a.equal(g.path, `driver/D1/${id}.png`);
  await fails(
    () => t.begin({ attemptId: otherId, sha256: "a".repeat(64) }),
    409,
  );
});
Deno.test("missing upload never completes; the same intent can retry after a network failure", async () => {
  const t = setup();
  await t.begin();
  await fails(
    () => t.call({ action: "complete", deliveryId: "D1", attemptId: id }),
    409,
  );
  a.equal(t.db.docs.get("deliveries/D1")!.status, "arrived");
  await t.upload();
  const result = await t.call({
    action: "complete",
    deliveryId: "D1",
    attemptId: id,
  });
  a.equal(result.state, "completed");
});
Deno.test("real bytes are verified before atomic proof, completion and authorized alerts", async () => {
  const t = setup();
  await t.upload();
  const result = await t.call({
    action: "complete",
    deliveryId: "D1",
    attemptId: id,
  });
  const proof = result.proof as Data;
  a.equal(proof.verificationStatus, "verified");
  a.equal(proof.photoUrl, undefined);
  a.equal(proof.sha256, image.sha256);
  a.equal(proof.bucket, "delivery-proofs");
  a.equal(t.db.docs.get("deliveries/D1")!.status, "completed");
  a.equal(t.db.docs.get(`proofUploads/${id}`)!.state, "committed");
  a.deepEqual(t.db.docs.get("notifications/proof-D1")!.recipientIds, [
    "manager",
  ]);
  a.equal(t.storage.removed.length, 0);
  const duplicate = await t.call({
    action: "complete",
    deliveryId: "D1",
    attemptId: id,
  });
  a.deepEqual(duplicate.proof, proof);
  a.equal(t.storage.downloads, 1);
});
Deno.test("failed Firestore commit retains immutable image for retry and never reports success", async () => {
  const t = setup();
  const g = await t.upload();
  t.db.failCompletionOnce = true;
  await fails(
    () => t.call({ action: "complete", deliveryId: "D1", attemptId: id }),
    503,
  );
  a.equal(t.db.docs.has("deliveryProofs/D1"), false);
  a.equal(t.db.docs.get("deliveries/D1")!.status, "arrived");
  a.equal(t.storage.objects.has(String(g.path)), true);
  await t.begin();
  const retry = await t.call({
    action: "complete",
    deliveryId: "D1",
    attemptId: id,
  });
  a.equal(retry.state, "completed");
});
Deno.test("content mismatch is rejected and its orphan is cleaned", async () => {
  const t = setup();
  const g = await t.upload();
  t.storage.objects.get(String(g.path))!.bytes = new Uint8Array([1, 2, 3]);
  await fails(
    () => t.call({ action: "complete", deliveryId: "D1", attemptId: id }),
    422,
  );
  a.equal(t.storage.objects.size, 0);
  a.equal(t.db.docs.has("deliveryProofs/D1"), false);
});
Deno.test("ownership/status/role changes during verification prevent completion", async () => {
  for (const mutation of ["cancel", "reassign", "revoke"]) {
    const t = setup();
    await t.upload();
    t.storage.beforeDownload = async () => {
      if (mutation === "cancel") {
        t.db.docs.get("deliveries/D1")!.status = "cancelled";
      }
      if (mutation === "reassign") {
        t.db.docs.get("deliveries/D1")!.driverId = "other";
      }
      if (mutation === "revoke") {
        t.db.docs.get("users/driver")!.role = "invalid";
      }
    };
    await a.rejects(() =>
      t.call({ action: "complete", deliveryId: "D1", attemptId: id })
    );
    a.equal(t.db.docs.has("deliveryProofs/D1"), false);
  }
});
Deno.test("cleanup wins the race without permitting completion; cleanup failure is reconcilable", async () => {
  const t = setup();
  const g = await t.upload();
  t.storage.beforeDownload = async () => {
    t.storage.beforeDownload = undefined;
    await t.broker.cleanup(id, "driver", true);
  };
  await fails(
    () => t.call({ action: "complete", deliveryId: "D1", attemptId: id }),
    409,
  );
  a.equal(t.db.docs.has("deliveryProofs/D1"), false);
  a.equal(t.storage.objects.has(String(g.path)), false);
  const next = setup();
  await next.upload();
  next.storage.failDelete = true;
  await fails(() => next.call({ action: "discard", deliveryId: "D1" }), 503);
  a.equal(next.db.docs.get(`proofUploads/${id}`)!.state, "cleanup");
  const result = await next.call({ action: "reconcile" }, "manager");
  a.deepEqual(result.failedAttempts, []);
  a.equal(next.storage.objects.size, 0);
});
Deno.test("existing valid proof is never deleted or replaced by retry/cleanup", async () => {
  const t = setup();
  const g = await t.upload();
  await t.call({ action: "complete", deliveryId: "D1", attemptId: id });
  await t.broker.cleanup(id, "driver", true);
  a.equal(t.storage.objects.has(String(g.path)), true);
  await fails(
    () => t.begin({ attemptId: otherId, sha256: "a".repeat(64) }),
    409,
  );
});
Deno.test("only approved manager/assigned driver can obtain a short-lived private proof URL", async () => {
  const t = setup();
  await t.upload();
  await t.call({ action: "complete", deliveryId: "D1", attemptId: id });
  const view = await t.call({ action: "view", deliveryId: "D1" }, "manager");
  a.equal(view.expiresIn, 60);
  a.match(String(view.url), /object\/sign\/delivery-proofs/);
  await fails(() => t.call({ action: "view", deliveryId: "D1" }, "other"), 403);
  t.db.docs.get("users/manager")!.role = "invalid";
  await fails(
    () => t.call({ action: "view", deliveryId: "D1" }, "manager"),
    403,
  );
});
Deno.test("expired attempts and late orphan uploads are repeatedly reconciled without touching proofs", async () => {
  const t = setup();
  const g = await t.upload();
  t.advance();
  await t.call({ action: "reconcile" }, "manager");
  a.equal(t.storage.objects.size, 0);
  t.storage.objects.set(String(g.path), { bytes, mimeType: "image/png" });
  await t.call({ action: "reconcile" }, "manager");
  a.equal(t.storage.objects.size, 0);
  await fails(() => t.call({ action: "reconcile" }, "driver"), 403);
});
