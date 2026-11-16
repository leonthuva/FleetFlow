import {
  ApiError,
  attemptId,
  BUCKET,
  type Data,
  type Dependencies,
  type Grant,
  type Identity,
  MAX_BYTES,
  proofPath,
  requireDriver,
  safeId,
  SERVER_TIME,
} from "./types.ts";
const managerRoles = ["admin", "dispatcher"];
function fields(value: unknown): Data {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ApiError(400, "invalid_request", "A JSON object is required.");
  }
  return value as Data;
}
function text(value: unknown, limit: number): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string" || value.length > limit) {
    throw new ApiError(
      400,
      "invalid_metadata",
      "Proof text is invalid or too long.",
    );
  }
  return value.trim();
}
function asGrant(doc: Data): Grant {
  return {
    attemptId: String(doc.attemptId),
    deliveryId: String(doc.deliveryId),
    driverId: String(doc.driverId),
    path: String(doc.path),
    mimeType: String(doc.mimeType),
    sizeBytes: Number(doc.sizeBytes),
    sha256: String(doc.sha256),
    expiresAt: String(doc.expiresAt),
  };
}
export class ProofBroker {
  constructor(private deps: Dependencies) {}
  async execute(identity: Identity, value: unknown): Promise<Data> {
    const body = fields(value);
    const uid = safeId(identity.uid, "Firebase UID");
    if (body.action === "reconcile") return this.reconcile(uid, body);
    const deliveryId = safeId(body.deliveryId, "delivery ID");
    switch (body.action) {
      case "begin":
        return this.begin(uid, deliveryId, body);
      case "complete":
        return this.complete(uid, deliveryId, attemptId(body.attemptId));
      case "view":
        return this.view(uid, deliveryId);
      case "discard":
        return this.discard(uid, deliveryId);
      default:
        throw new ApiError(400, "unknown_action", "Unknown proof operation.");
    }
  }
  private async begin(
    uid: string,
    deliveryId: string,
    body: Data,
  ): Promise<Data> {
    const requestedId = attemptId(body.attemptId);
    const mime = text(body.mimeType, 32);
    const size = Number(body.sizeBytes);
    const digest = text(body.sha256, 64);
    if (
      !Number.isSafeInteger(size) || size < 1 || size > MAX_BYTES ||
      !/^[0-9a-f]{64}$/.test(digest)
    ) {
      throw new ApiError(
        400,
        "invalid_image",
        "A valid image size and SHA-256 are required.",
      );
    }
    const path = proofPath(uid, deliveryId, requestedId, mime);
    const notes = text(body.notes, 2000),
      recipientName = text(body.recipientName, 200);
    const capturedAt = body.capturedAt === undefined
      ? null
      : new Date(String(body.capturedAt));
    if (
      capturedAt &&
      (!Number.isFinite(capturedAt.getTime()) ||
        capturedAt.getTime() > this.deps.now().getTime() + 300_000)
    ) {
      throw new ApiError(
        400,
        "invalid_capture_time",
        "Capture time is invalid.",
      );
    }
    const capturedLocation = body.capturedLocation === undefined
      ? {}
      : fields(body.capturedLocation);
    const location: Data = {};
    if (Object.keys(capturedLocation).length) {
      const lat = capturedLocation.lat, lng = capturedLocation.lng;
      if (
        typeof lat !== "number" || typeof lng !== "number" ||
        !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 ||
        Math.abs(lng) > 180
      ) {
        throw new ApiError(
          400,
          "invalid_location",
          "Capture coordinates are invalid.",
        );
      }
      location.lat = lat;
      location.lng = lng;
      if (capturedLocation.accuracy !== undefined) {
        const a = capturedLocation.accuracy;
        if (typeof a !== "number" || !Number.isFinite(a) || a < 0) {
          throw new ApiError(
            400,
            "invalid_location",
            "Capture accuracy is invalid.",
          );
        }
        location.accuracy = a;
      }
    }
    const result = await this.deps.db.transaction(async (tx) => {
      const user = await tx.get(`users/${uid}`),
        delivery = await tx.get(`deliveries/${deliveryId}`),
        proof = await tx.get(`deliveryProofs/${deliveryId}`),
        lock = await tx.get(`proofUploadLocks/${deliveryId}`);
      requireDriver(user, delivery, uid);
      if (proof) {
        if (
          delivery?.status === "completed" && proof.driverId === uid &&
          proof.sha256 === digest && proof.verificationStatus === "verified"
        ) return { proof };
        throw new ApiError(
          409,
          "proof_exists",
          "An immutable proof already exists for this delivery.",
        );
      }
      if (delivery?.status !== "arrived") {
        throw new ApiError(
          409,
          "not_arrived",
          "Proof can only be submitted at the arrived stage.",
        );
      }
      if (lock) {
        const existing = await tx.get(
          `proofUploads/${safeId(lock.attemptId, "upload attempt")}`,
        );
        if (
          existing?.driverId === uid && existing.sha256 === digest &&
          existing.mimeType === mime && existing.sizeBytes === size &&
          existing.state === "pending" &&
          new Date(String(existing.expiresAt)).getTime() >
            this.deps.now().getTime()
        ) {
          tx.update(`proofUploads/${String(existing.attemptId)}`, {
            notes,
            recipientName,
            capturedAt: capturedAt?.toISOString() ?? null,
            capturedLocation: location,
          });
          return { grant: asGrant(existing) };
        }
        throw new ApiError(
          409,
          "upload_pending",
          "An unfinished upload exists. Discard it or allow reconciliation before starting another photo.",
        );
      }
      const previous = await tx.get(`proofUploads/${requestedId}`);
      if (previous) {
        throw new ApiError(
          409,
          "attempt_used",
          "This upload attempt has already been used.",
        );
      }
      const grant: Grant = {
        attemptId: requestedId,
        deliveryId,
        driverId: uid,
        path,
        mimeType: mime,
        sizeBytes: size,
        sha256: digest,
        expiresAt: new Date(this.deps.now().getTime() + 15 * 60_000)
          .toISOString(),
      };
      tx.set(`proofUploads/${requestedId}`, {
        ...grant,
        state: "pending",
        createdAt: SERVER_TIME,
        notes,
        recipientName,
        capturedAt: capturedAt?.toISOString() ?? null,
        capturedLocation: location,
      });
      tx.set(`proofUploadLocks/${deliveryId}`, {
        attemptId: requestedId,
        driverId: uid,
      });
      return { grant };
    });
    if (result.proof) return { state: "completed", proof: result.proof };
    // Intent is durable before an RLS grant exists. Retrying begin repairs a failed grant write.
    await this.deps.storage.grant(result.grant!);
    return { state: "pending", bucket: BUCKET, ...result.grant };
  }
  private async complete(
    uid: string,
    deliveryId: string,
    id: string,
  ): Promise<Data> {
    const user = await this.deps.db.get(`users/${uid}`),
      delivery = await this.deps.db.get(`deliveries/${deliveryId}`),
      prior = await this.deps.db.get(`deliveryProofs/${deliveryId}`);
    requireDriver(user, delivery, uid);
    if (prior) {
      if (
        prior.driverId === uid && prior.deliveryId === deliveryId &&
        prior.uploadId === id && prior.verificationStatus === "verified" &&
        delivery?.status === "completed"
      ) {
        return {
          state: "completed",
          proof: prior,
          notificationWarning: prior.notificationWarning ?? null,
        };
      }
      throw new ApiError(
        409,
        "proof_exists",
        "This delivery already has a different proof.",
      );
    }
    const intent = await this.deps.db.get(`proofUploads/${id}`);
    if (
      !intent || intent.driverId !== uid || intent.deliveryId !== deliveryId
    ) {
      throw new ApiError(
        403,
        "unknown_attempt",
        "This upload attempt is not authorized.",
      );
    }
    if (
      intent.state !== "pending" || delivery?.status !== "arrived" ||
      new Date(String(intent.expiresAt)).getTime() <= this.deps.now().getTime()
    ) {
      throw new ApiError(
        409,
        "attempt_closed",
        "This upload expired or was closed; discard it before retrying.",
      );
    }
    const grant = asGrant(intent);
    if (grant.path !== proofPath(uid, deliveryId, id, grant.mimeType)) {
      throw new ApiError(
        403,
        "invalid_path",
        "Stored upload authorization does not match its owner.",
      );
    }
    // Download real private bytes. No client-supplied URL, existence flag or MIME is trusted.
    let image;
    try {
      const object = await this.deps.storage.download(grant.path);
      image = await this.deps.inspectImage(object.bytes);
      if (
        image.sha256 !== grant.sha256 || image.sizeBytes !== grant.sizeBytes ||
        image.mimeType !== grant.mimeType ||
        object.mimeType.split(";")[0] !== grant.mimeType
      ) {
        throw new ApiError(
          422,
          "image_mismatch",
          "Uploaded image does not match its authorized content.",
        );
      }
    } catch (e) {
      // Missing/network-failed uploads remain pending for retry; invalid bytes are quarantined/cleaned.
      if (e instanceof ApiError && e.status === 422) {
        await this.cleanup(id, uid, true);
      }
      throw e;
    }
    await this.deps.storage.closeGrant(id);
    const result = await this.deps.db.transaction(async (tx) => {
      const currentUser = await tx.get(`users/${uid}`),
        current = await tx.get(`deliveries/${deliveryId}`),
        proof = await tx.get(`deliveryProofs/${deliveryId}`),
        attempt = await tx.get(`proofUploads/${id}`),
        lock = await tx.get(`proofUploadLocks/${deliveryId}`),
        targets = await tx.get("notificationTargets/managers");
      requireDriver(currentUser, current, uid);
      if (proof) {
        if (
          proof.driverId === uid && proof.deliveryId === deliveryId &&
          proof.uploadId === id && proof.verificationStatus === "verified" &&
          current?.status === "completed"
        ) return { proof };
        throw new ApiError(
          409,
          "proof_exists",
          "Existing proof cannot be replaced.",
        );
      }
      if (
        current?.status !== "arrived" || attempt?.state !== "pending" ||
        lock?.attemptId !== id ||
        new Date(String(attempt.expiresAt)).getTime() <=
          this.deps.now().getTime()
      ) {
        throw new ApiError(
          409,
          "delivery_changed",
          "Delivery authorization changed during verification. No completion was committed.",
        );
      }
      const recipientIds = Array.isArray(targets?.uids)
        ? [
          ...new Set(targets.uids.filter((x): x is string =>
            typeof x === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(x)
          )),
        ]
        : [];
      // Recheck each configured target's authoritative role before sending private alerts.
      if (recipientIds.length > 100) {
        throw new ApiError(
          503,
          "too_many_targets",
          "Manager alert recipients require administrator review.",
        );
      }
      const approved: string[] = [];
      for (const target of recipientIds) {
        if (
          managerRoles.includes(String((await tx.get(`users/${target}`))?.role))
        ) approved.push(target);
      }
      const warning = approved.length
        ? null
        : "Delivery completed, but no approved manager alert recipients were configured.";
      const record: Data = {
        schemaVersion: 2,
        deliveryId,
        driverId: uid,
        uploadId: id,
        storageProvider: "supabase",
        bucket: BUCKET,
        storagePath: grant.path,
        sha256: image.sha256,
        mimeType: image.mimeType,
        sizeBytes: image.sizeBytes,
        width: image.width,
        height: image.height,
        verificationStatus: "verified",
        verifiedAt: SERVER_TIME,
        timestamp: SERVER_TIME,
        createdAt: SERVER_TIME,
        capturedAt: attempt.capturedAt ?? null,
        capturedLocation: attempt.capturedLocation ?? {},
        notes: attempt.notes ?? "",
        recipientName: attempt.recipientName ?? "",
        notificationWarning: warning,
      };
      tx.set(`deliveryProofs/${deliveryId}`, record);
      tx.update(`deliveries/${deliveryId}`, {
        status: "completed",
        completedAt: SERVER_TIME,
        updatedAt: SERVER_TIME,
        proofId: deliveryId,
        proofStorageProvider: "supabase",
        proofStoragePath: grant.path,
        proofPhotoUrl: null,
        signatureNotes: attempt.notes ?? "",
      });
      tx.update(`proofUploads/${id}`, {
        state: "committed",
        committedAt: SERVER_TIME,
      });
      tx.delete(`proofUploadLocks/${deliveryId}`);
      if (approved.length) {
        tx.set(`notifications/proof-${deliveryId}`, {
          createdBy: uid,
          audience: "managers",
          recipientIds: approved,
          recipientRoles: ["admin", "dispatcher"],
          title: "Proof verified and delivery completed",
          message: `Delivery ${deliveryId} completed with verified proof.`,
          type: "delivery_completed",
          timestamp: SERVER_TIME,
          readBy: [],
          metadata: { deliveryId, proofId: deliveryId },
        });
      }
      return { proof: record };
    });
    // Read committed server timestamps. If the response is lost, the same attempt returns this proof on retry.
    const proof = await this.deps.db.get(`deliveryProofs/${deliveryId}`) ??
      result.proof;
    return {
      state: "completed",
      proof,
      notificationWarning: proof.notificationWarning ?? null,
    };
  }
  private async view(uid: string, deliveryId: string): Promise<Data> {
    const user = await this.deps.db.get(`users/${uid}`),
      delivery = await this.deps.db.get(`deliveries/${deliveryId}`),
      proof = await this.deps.db.get(`deliveryProofs/${deliveryId}`);
    if (
      !user ||
      (!managerRoles.includes(String(user.role)) &&
        !(user.role === "driver" && delivery?.driverId === uid))
    ) {
      throw new ApiError(
        403,
        "view_denied",
        "Proof access is restricted to managers and the assigned driver.",
      );
    }
    if (
      !proof || delivery?.status !== "completed" ||
      proof.verificationStatus !== "verified" ||
      proof.storageProvider !== "supabase" || proof.bucket !== BUCKET ||
      proof.driverId !== delivery.driverId ||
      proof.storagePath !==
        proofPath(
          String(proof.driverId),
          deliveryId,
          attemptId(proof.uploadId),
          String(proof.mimeType),
        )
    ) {
      throw new ApiError(
        404,
        "proof_unavailable",
        "Verified proof is not available.",
      );
    }
    const expiresIn = 60;
    return {
      url: await this.deps.storage.signedRead(
        String(proof.storagePath),
        expiresIn,
      ),
      expiresIn,
    };
  }
  private async discard(uid: string, deliveryId: string): Promise<Data> {
    const user = await this.deps.db.get(`users/${uid}`),
      delivery = await this.deps.db.get(`deliveries/${deliveryId}`);
    requireDriver(user, delivery, uid);
    const lock = await this.deps.db.get(`proofUploadLocks/${deliveryId}`);
    if (!lock) return { state: "nothing_pending" };
    await this.cleanup(safeId(lock.attemptId), uid, true);
    return { state: "discarded" };
  }
  async cleanup(id: string, actorUid: string, force = false): Promise<boolean> {
    const claimed = await this.deps.db.transaction(async (tx) => {
      const attempt = await tx.get(`proofUploads/${id}`);
      if (!attempt) return null;
      const deliveryId = safeId(attempt.deliveryId);
      const proof = await tx.get(`deliveryProofs/${deliveryId}`),
        lock = await tx.get(`proofUploadLocks/${deliveryId}`);
      if (
        String(attempt.path) !==
          proofPath(
            safeId(attempt.driverId),
            deliveryId,
            attemptId(id),
            String(attempt.mimeType),
          )
      ) {
        throw new ApiError(
          403,
          "invalid_path",
          "Cleanup authorization has an invalid object path.",
        );
      }
      if (attempt.driverId !== actorUid) {
        throw new ApiError(
          403,
          "cleanup_denied",
          "This upload is owned by another driver.",
        );
      }
      if (
        proof?.storagePath === attempt.path || attempt.state === "committed"
      ) return null; // Never delete valid evidence.
      if (
        attempt.state === "pending" && !force &&
        new Date(String(attempt.expiresAt)).getTime() >
          this.deps.now().getTime()
      ) return null;
      tx.update(`proofUploads/${id}`, {
        state: "cleanup",
        cleanupAt: SERVER_TIME,
      });
      return {
        ...attempt,
        path: String(attempt.path),
        deliveryId,
        ownsLock: lock?.attemptId === id,
      };
    });
    if (!claimed) return false;
    await this.deps.storage.closeGrant(id);
    await this.deps.storage.remove(String(claimed.path));
    await this.deps.db.transaction(async (tx) => {
      const attempt = await tx.get(`proofUploads/${id}`),
        proof = await tx.get(`deliveryProofs/${claimed.deliveryId}`),
        lock = await tx.get(`proofUploadLocks/${claimed.deliveryId}`);
      if (
        proof?.storagePath === claimed.path || attempt?.state === "committed"
      ) {
        throw new ApiError(
          409,
          "proof_protected",
          "A committed proof cannot be removed.",
        );
      }
      tx.update(`proofUploads/${id}`, {
        state: "cleaned",
        cleanedAt: SERVER_TIME,
      });
      if (lock?.attemptId === id) {
        tx.delete(`proofUploadLocks/${claimed.deliveryId}`);
      }
    });
    return true;
  }
  private async reconcile(uid: string, body: Data): Promise<Data> {
    if ((await this.deps.db.get(`users/${uid}`))?.role !== "admin") {
      throw new ApiError(
        403,
        "admin_required",
        "Only an administrator may reconcile uploads.",
      );
    }
    const page = await this.deps.db.listAttempts(
      20,
      typeof body.cursor === "string" ? body.cursor : undefined,
    );
    let cleaned = 0;
    const failures: string[] = [];
    for (const row of page.items) {
      if (["pending", "cleanup", "cleaned"].includes(String(row.state))) {
        try {
          if (
            await this.cleanup(attemptId(row.attemptId), safeId(row.driverId))
          ) cleaned++;
        } catch {
          failures.push(String(row.attemptId));
        }
      } else if (row.state === "committed") {
        try {
          await this.deps.storage.closeGrant(String(row.attemptId));
        } catch {
          failures.push(String(row.attemptId));
        }
      }
    }
    return {
      scanned: page.items.length,
      cleaned,
      failedAttempts: failures,
      nextCursor: page.cursor ?? null,
    };
  }
}
