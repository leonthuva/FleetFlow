import {
  ApiError,
  type Data,
  type Database,
  type Grant,
  type PrivateStorage,
  type Transaction,
} from "../functions/proof-broker/types.ts";
export class MemoryDatabase implements Database {
  docs = new Map<string, Data>();
  failCompletionOnce = false;
  private serial = Promise.resolve();
  constructor(readonly now: () => Date) {}
  async get(path: string) {
    return structuredClone(this.docs.get(path) ?? null);
  }
  async transaction<T>(action: (tx: Transaction) => Promise<T>): Promise<T> {
    const prior = this.serial;
    let release!: () => void;
    this.serial = new Promise<void>((r) => release = r);
    await prior;
    const draft = structuredClone(this.docs);
    const resolve = (data: Data): Data =>
      Object.fromEntries(
        Object.entries(data).map((
          [k, v],
        ) => [
          k,
          v && typeof v === "object" && (v as Data).__serverTimestamp === true
            ? this.now().toISOString()
            : v,
        ]),
      );
    try {
      const result = await action({
        get: async (p) => structuredClone(draft.get(p) ?? null),
        set: (p, d) => {
          draft.set(p, resolve(d));
        },
        update: (p, d) => {
          if (!draft.has(p)) throw new Error("Missing document");
          draft.set(p, { ...draft.get(p), ...resolve(d) });
        },
        delete: (p) => {
          draft.delete(p);
        },
      });
      if (
        this.failCompletionOnce &&
        [...draft].some(([p, d]) =>
          p.startsWith("deliveries/") && d.status === "completed"
        )
      ) {
        this.failCompletionOnce = false;
        throw new ApiError(503, "database_failed", "Injected commit failure");
      }
      this.docs = draft;
      return result;
    } finally {
      release();
    }
  }
  async listAttempts(limit: number) {
    return {
      items: [...this.docs].filter(([p]) => p.startsWith("proofUploads/")).map((
        [, d],
      ) => structuredClone(d)).slice(0, limit),
    };
  }
}
export class MemoryStorage implements PrivateStorage {
  grants = new Map<string, Grant>();
  closed = new Set<string>();
  objects = new Map<string, { bytes: Uint8Array; mimeType: string }>();
  removed: string[] = [];
  downloads = 0;
  failGrant = false;
  failDelete = false;
  beforeDownload?: () => Promise<void>;
  async grant(g: Grant) {
    if (this.failGrant) {
      this.failGrant = false;
      throw new ApiError(503, "grant_failed", "Injected grant failure");
    }
    this.grants.set(g.attemptId, structuredClone(g));
  }
  async closeGrant(id: string) {
    this.closed.add(id);
  }
  async download(path: string) {
    this.downloads++;
    await this.beforeDownload?.();
    const value = this.objects.get(path);
    if (!value) throw new ApiError(409, "upload_missing", "Upload missing");
    return value;
  }
  async remove(path: string) {
    if (this.failDelete) {
      this.failDelete = false;
      throw new ApiError(503, "cleanup_failed", "Injected cleanup failure");
    }
    this.removed.push(path);
    this.objects.delete(path);
  }
  async signedRead(path: string, seconds: number) {
    return `https://example.supabase.co/storage/v1/object/sign/delivery-proofs/${path}?token=test-expiry-${seconds}`;
  }
}
