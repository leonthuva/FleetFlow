export type Data = Record<string, unknown>;
export const SERVER_TIME = { __serverTimestamp: true } as const;
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}
export interface Transaction {
  get(path: string): Promise<Data | null>;
  set(path: string, data: Data): void;
  update(path: string, data: Data): void;
  delete(path: string): void;
}
export interface Database {
  get(path: string): Promise<Data | null>;
  transaction<T>(action: (tx: Transaction) => Promise<T>): Promise<T>;
  listAttempts(
    limit: number,
    cursor?: string,
  ): Promise<{ items: Data[]; cursor?: string }>;
}
export interface Identity {
  uid: string;
}
export interface Grant {
  attemptId: string;
  deliveryId: string;
  driverId: string;
  path: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  expiresAt: string;
}
export interface PrivateStorage {
  grant(grant: Grant): Promise<void>;
  closeGrant(attemptId: string): Promise<void>;
  download(path: string): Promise<{ bytes: Uint8Array; mimeType: string }>;
  remove(path: string): Promise<void>;
  signedRead(path: string, seconds: number): Promise<string>;
}
export interface ImageInfo {
  mimeType: string;
  width: number;
  height: number;
  sizeBytes: number;
  sha256: string;
}
export interface Dependencies {
  db: Database;
  storage: PrivateStorage;
  inspectImage(bytes: Uint8Array): Promise<ImageInfo>;
  now(): Date;
}
export const BUCKET = "delivery-proofs";
export const MAX_BYTES = 5_000_000;
export const MAX_PIXELS = 4_000_000;
export function safeId(value: unknown, label = "ID"): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new ApiError(400, "invalid_id", `Invalid ${label}.`);
  }
  return value;
}
export function attemptId(value: unknown): string {
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(value)
  ) {
    throw new ApiError(
      400,
      "invalid_attempt",
      "A UUID v4 idempotency key is required.",
    );
  }
  return value;
}
export function requireDriver(
  user: Data | null,
  delivery: Data | null,
  uid: string,
): void {
  if (user?.role !== "driver" || !delivery || delivery.driverId !== uid) {
    throw new ApiError(
      403,
      "not_assigned",
      "Only the assigned driver may submit proof.",
    );
  }
}
export function proofPath(
  uid: string,
  deliveryId: string,
  id: string,
  mime: string,
): string {
  const extension =
    { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" }[mime];
  if (!extension) {
    throw new ApiError(400, "invalid_image", "JPEG, PNG or WebP is required.");
  }
  return `${safeId(uid)}/${safeId(deliveryId)}/${attemptId(id)}.${extension}`;
}
