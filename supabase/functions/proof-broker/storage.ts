import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ApiError, BUCKET, type Grant, type PrivateStorage } from "./types.ts";
export class SupabasePrivateStorage implements PrivateStorage {
  private client: SupabaseClient;
  constructor(url: string, serverKey: string) {
    this.client = createClient(url, serverKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  async grant(g: Grant): Promise<void> {
    const { error } = await this.client.rpc("fleetflow_put_proof_grant", {
      p_attempt_id: g.attemptId,
      p_driver_uid: g.driverId,
      p_delivery_id: g.deliveryId,
      p_object_name: g.path,
      p_mime_type: g.mimeType,
      p_size_bytes: g.sizeBytes,
      p_sha256: g.sha256,
      p_expires_at: g.expiresAt,
    });
    if (error) {
      throw new ApiError(
        503,
        "upload_authorization",
        "Upload authorization could not be saved. Retry with the same photograph.",
      );
    }
  }
  async closeGrant(id: string): Promise<void> {
    const { error } = await this.client.rpc("fleetflow_close_proof_grant", {
      p_attempt_id: id,
    });
    if (error) {
      throw new ApiError(
        503,
        "grant_close",
        "Upload authorization could not be closed safely. Retry later.",
      );
    }
  }
  async download(
    path: string,
  ): Promise<{ bytes: Uint8Array; mimeType: string }> {
    const { data, error } = await this.client.storage.from(BUCKET).download(
      path,
    );
    if (error || !data) {
      throw new ApiError(
        409,
        "upload_missing",
        "The private upload is not available yet. Retry the same photo; do not mark the delivery completed.",
      );
    }
    return {
      bytes: new Uint8Array(await data.arrayBuffer()),
      mimeType: data.type,
    };
  }
  async remove(path: string): Promise<void> {
    const { error } = await this.client.storage.from(BUCKET).remove([path]);
    if (error) {
      throw new ApiError(
        503,
        "cleanup_pending",
        "Orphan cleanup could not finish; reconciliation will retry.",
      );
    }
  }
  async signedRead(path: string, seconds: number): Promise<string> {
    const { data, error } = await this.client.storage.from(BUCKET)
      .createSignedUrl(path, seconds);
    if (error || !data?.signedUrl) {
      throw new ApiError(
        503,
        "proof_view_failed",
        "Private proof viewing is temporarily unavailable.",
      );
    }
    return data.signedUrl;
  }
}
