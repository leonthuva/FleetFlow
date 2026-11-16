import { strict as a } from "node:assert";
import { FirestoreRest } from "../functions/proof-broker/firestore.ts";
import { inspectImage } from "../functions/proof-broker/images.ts";
import { type Data, SERVER_TIME } from "../functions/proof-broker/types.ts";
// Explicit opt-in only. This creates a synthetic assignment and retains its immutable audit proof.
const enabled = Deno.env.get("RUN_LIVE_PROOF_TESTS") === "true";
Deno.test({
  name:
    "LIVE real Firebase manager assignment -> driver lifecycle -> private Supabase proof -> atomic completion -> manager view",
  ignore: !enabled,
  fn: async () => {
    const url = Deno.env.get("SUPABASE_URL"),
      key = Deno.env.get("SUPABASE_PUBLISHABLE_KEY"),
      manager = Deno.env.get("FIREBASE_MANAGER_ID_TOKEN"),
      driver = Deno.env.get("FIREBASE_DRIVER_ID_TOKEN");
    if (!url || !key || !manager || !driver) {
      throw new Error(
        "BLOCKED: public project configuration, approved driver/manager ID tokens and deployed broker are required.",
      );
    }
    const subject = (jwt: string) => {
      const segment = jwt.split(".")[1].replaceAll("-", "+").replaceAll(
        "_",
        "/",
      );
      return JSON.parse(atob(segment)).sub as string;
    };
    const managerUid = subject(manager),
      driverUid = subject(driver),
      managerDb = new FirestoreRest(
        "fleetflow-dev-29e55",
        () => Promise.resolve(manager),
      ),
      driverDb = new FirestoreRest(
        "fleetflow-dev-29e55",
        () => Promise.resolve(driver),
      );
    a.notEqual(managerUid, driverUid);
    a.ok(
      ["admin", "dispatcher"].includes(
        String((await managerDb.get(`users/${managerUid}`))?.role),
      ),
    );
    const driverProfile = await managerDb.get(`users/${driverUid}`);
    a.equal(driverProfile?.role, "driver");
    a.equal(driverProfile?.onShift, true);
    const deliveryId = await managerDb.transaction(async (tx) => {
      const counter = await tx.get("counters/deliveries"),
        value = Number(counter?.value ?? 0) + 1,
        id = `DEL-${String(value).padStart(4, "0")}`;
      a.equal(await tx.get(`deliveries/${id}`), null);
      tx.set("counters/deliveries", { value });
      tx.set(`deliveries/${id}`, {
        driverId: driverUid,
        status: "assigned",
        createdBy: managerUid,
        createdAt: SERVER_TIME,
        assignedAt: SERVER_TIME,
        updatedAt: SERVER_TIME,
        recipientName: "Task 16 QA recipient",
        recipientPhone: "0000000000",
        pickupAddress: "Synthetic QA depot",
        address: "Synthetic QA destination",
        latitude: 6.9,
        longitude: 79.8,
        priority: "standard",
        packageDescription:
          "Disposable Task 16 acceptance fixture; immutable proof retained",
      });
      return id;
    });
    for (
      const [status, field] of [["picked_up", "pickedUpAt"], [
        "in_transit",
        "inTransitAt",
      ], ["arrived", "arrivedAt"]]
    ) {
      await driverDb.transaction(async (tx) => {
        await tx.get(`deliveries/${deliveryId}`);
        tx.update(`deliveries/${deliveryId}`, {
          status,
          [field]: SERVER_TIME,
          updatedAt: SERVER_TIME,
        });
      });
    }
    const invoke = async (token: string, body: Data) => {
      const response = await fetch(`${url}/functions/v1/proof-broker`, {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      const data = await response.json();
      a.equal(
        response.status,
        200,
        `Proof operation ${body.action} failed (HTTP ${response.status}); no credentials or private response are logged.`,
      );
      return data as Data;
    };
    const bytes = await Deno.readFile(
        new URL("./fixtures/proof.png", import.meta.url),
      ),
      image = await inspectImage(bytes),
      attemptId = crypto.randomUUID();
    const grant = await invoke(driver, {
      action: "begin",
      deliveryId,
      attemptId,
      mimeType: image.mimeType,
      sizeBytes: image.sizeBytes,
      sha256: image.sha256,
    });
    const path = String(grant.path);
    a.equal(grant.bucket, "delivery-proofs");
    a.equal(path, `${driverUid}/${deliveryId}/${attemptId}.png`);
    const upload = await fetch(
      `${url}/storage/v1/object/delivery-proofs/${path}`,
      {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${driver}`,
          "Content-Type": "image/png",
          "x-upsert": "false",
        },
        body: bytes,
      },
    );
    await upload.text();
    a.equal(upload.status, 200);
    const result = await invoke(driver, {
      action: "complete",
      deliveryId,
      attemptId,
    });
    const proof = result.proof as Data;
    a.equal(proof.sha256, image.sha256);
    a.equal(proof.verificationStatus, "verified");
    a.equal(proof.photoUrl, undefined);
    a.equal(
      (await driverDb.get(`deliveries/${deliveryId}`))?.status,
      "completed",
    );
    a.equal(
      (await managerDb.get(`deliveryProofs/${deliveryId}`))?.storagePath,
      path,
    );
    const duplicate = await invoke(driver, {
      action: "complete",
      deliveryId,
      attemptId,
    });
    a.equal((duplicate.proof as Data).uploadId, attemptId);
    const view = await invoke(manager, { action: "view", deliveryId });
    a.equal(view.expiresIn, 60);
    const photograph = await fetch(String(view.url));
    a.equal(photograph.status, 200);
    a.equal(
      (await inspectImage(new Uint8Array(await photograph.arrayBuffer())))
        .sha256,
      image.sha256,
    );
    console.log(
      `LIVE acceptance passed for synthetic delivery ${deliveryId}; its private verified proof is deliberately retained. No tokens or signed URLs were logged.`,
    );
  },
});
