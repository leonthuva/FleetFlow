import { strict as a } from "node:assert";
import { FirestoreRest } from "../functions/proof-broker/firestore.ts";
import { ProofBroker } from "../functions/proof-broker/broker.ts";
import { inspectImage } from "../functions/proof-broker/images.ts";
import { type Data, SERVER_TIME } from "../functions/proof-broker/types.ts";
import { MemoryStorage } from "./fakes.ts";
const host = Deno.env.get("FIRESTORE_EMULATOR_HOST");
Deno.test({
  name:
    "REAL LOCAL FIRESTORE REST transactions atomically verify proof and complete; invalid ownership and cleanup cannot bypass",
  ignore: !host,
  fn: async () => {
    if (!host || !/^127\.0\.0\.1:|^localhost:/.test(host)) {
      throw new Error("Only a local emulator host is allowed for this test.");
    }
    const db = new FirestoreRest(
      "demo-fleetflow",
      () => Promise.resolve("owner"),
      `http://${host}/v1`,
    );
    await db.transaction(async (tx) => {
      tx.set("users/driver", { role: "driver" });
      tx.set("users/manager", { role: "admin" });
      tx.set("notificationTargets/managers", { uids: ["manager"] });
      tx.set("deliveries/REST_D1", {
        driverId: "driver",
        status: "arrived",
        createdAt: SERVER_TIME,
      });
    });
    const storage = new MemoryStorage(),
      broker = new ProofBroker({
        db,
        storage,
        inspectImage,
        now: () => new Date(),
      });
    const bytes = await Deno.readFile(
        new URL("./fixtures/proof.png", import.meta.url),
      ),
      image = await inspectImage(bytes),
      id = crypto.randomUUID();
    const grant = await broker.execute({ uid: "driver" }, {
      action: "begin",
      deliveryId: "REST_D1",
      attemptId: id,
      mimeType: image.mimeType,
      sizeBytes: image.sizeBytes,
      sha256: image.sha256,
    });
    storage.objects.set(String(grant.path), { bytes, mimeType: "image/png" });
    const completed = await broker.execute({ uid: "driver" }, {
      action: "complete",
      deliveryId: "REST_D1",
      attemptId: id,
    });
    const proof = completed.proof as Data;
    a.equal(proof.verificationStatus, "verified");
    a.equal(typeof proof.timestamp, "string");
    a.equal((await db.get("deliveries/REST_D1"))!.status, "completed");
    a.equal((await db.get(`proofUploads/${id}`))!.state, "committed");
    a.equal(await db.get("proofUploadLocks/REST_D1"), null);
    const retry = await broker.execute({ uid: "driver" }, {
      action: "complete",
      deliveryId: "REST_D1",
      attemptId: id,
    });
    a.deepEqual(retry.proof, proof);
    await broker.cleanup(id, "driver", true);
    a.equal(storage.objects.size, 1);
    await a.rejects(() =>
      broker.execute({ uid: "other" }, {
        action: "view",
        deliveryId: "REST_D1",
      })
    );
    const url = await broker.execute({ uid: "manager" }, {
      action: "view",
      deliveryId: "REST_D1",
    });
    a.equal(url.expiresIn, 60);
  },
});
