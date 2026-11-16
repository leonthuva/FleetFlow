import {
  ApiError,
  type Data,
  type Database,
  type Transaction,
} from "./types.ts";
interface Value {
  nullValue?: null;
  stringValue?: string;
  booleanValue?: boolean;
  integerValue?: string;
  doubleValue?: number;
  timestampValue?: string;
  mapValue?: { fields?: Record<string, Value> };
  arrayValue?: { values?: Value[] };
}
function encode(value: unknown): Value {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encode) } };
  }
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([k, v]) => [k, encode(v)]),
        ),
      },
    };
  }
  throw new Error("Unsupported Firestore value");
}
function decode(value: Value): unknown {
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) {
    return (value.arrayValue?.values ?? []).map(decode);
  }
  return Object.fromEntries(
    Object.entries(value.mapValue?.fields ?? {}).map((
      [k, v],
    ) => [k, decode(v)]),
  );
}
export class FirestoreRest implements Database {
  readonly documentRoot: string;
  constructor(
    readonly project: string,
    private accessToken: () => Promise<string>,
    private origin = "https://firestore.googleapis.com/v1",
  ) {
    this.documentRoot = `projects/${project}/databases/(default)/documents`;
  }
  private async request(
    path: string,
    method = "GET",
    body?: unknown,
  ): Promise<Data> {
    const response = await fetch(`${this.origin}/${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${await this.accessToken()}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    });
    if (response.status === 404 && method === "GET") return { missing: true };
    const data = await response.json();
    if (!response.ok) {
      const code = (data as Data).error as Data | undefined;
      throw new ApiError(
        response.status >= 500 ? 503 : response.status,
        String(code?.status ?? "firestore_error"),
        "The authoritative database operation failed. Retry safely.",
      );
    }
    return data as Data;
  }
  private async read(path: string, transaction?: string): Promise<Data | null> {
    // batchGet accepts the transaction as JSON bytes. It also avoids the emulator's
    // GET query-parser BYTE_STRING bug while retaining transaction consistency.
    let doc: Data;
    if (transaction) {
      const result = await this.request(
        `${this.documentRoot}:batchGet`,
        "POST",
        {
          documents: [`${this.documentRoot}/${path}`],
          transaction,
        },
      );
      const row = (Array.isArray(result) ? result[0] : result) as Data;
      doc = row?.found ? row.found as Data : { missing: true };
    } else {
      doc = await this.request(
        `${this.documentRoot}/${
          path.split("/").map(encodeURIComponent).join("/")
        }`,
      );
    }
    if (doc.missing) return null;
    return Object.fromEntries(
      Object.entries((doc.fields ?? {}) as Record<string, Value>).map((
        [k, v],
      ) => [k, decode(v)]),
    );
  }
  get(path: string): Promise<Data | null> {
    return this.read(path);
  }
  async transaction<T>(action: (tx: Transaction) => Promise<T>): Promise<T> {
    for (let count = 0; count < 5; count++) {
      const begin = await this.request(
        `${this.documentRoot}:beginTransaction`,
        "POST",
        { options: { readWrite: {} } },
      );
      const transaction = String(begin.transaction);
      const writes: Data[] = [];
      const write = (path: string, data: Data, patch: boolean) => {
        const transforms: Data[] = [];
        const normal: Record<string, Value> = {};
        for (const [key, value] of Object.entries(data)) {
          if (
            value && typeof value === "object" &&
            (value as Data).__serverTimestamp === true
          ) {
            transforms.push({
              fieldPath: key,
              setToServerValue: "REQUEST_TIME",
            });
          } else normal[key] = encode(value);
        }
        writes.push({
          update: { name: `${this.documentRoot}/${path}`, fields: normal },
          ...(patch
            ? {
              updateMask: { fieldPaths: Object.keys(normal) },
              currentDocument: { exists: true },
            }
            : {}),
          ...(transforms.length ? { updateTransforms: transforms } : {}),
        });
      };
      try {
        const result = await action({
          get: (path) => this.read(path, transaction),
          set: (path, data) => write(path, data, false),
          update: (path, data) => write(path, data, true),
          delete: (path) => {
            writes.push({ delete: `${this.documentRoot}/${path}` });
          },
        });
        await this.request(`${this.documentRoot}:commit`, "POST", {
          transaction,
          writes,
        });
        return result;
      } catch (e) {
        try {
          await this.request(`${this.documentRoot}:rollback`, "POST", {
            transaction,
          });
        } catch { /* The original error determines retry/response. */ }
        if (
          e instanceof ApiError &&
          ["ABORTED", "UNAVAILABLE"].includes(e.code) && count < 4
        ) continue;
        throw e;
      }
    }
    throw new ApiError(
      503,
      "transaction_retry",
      "Transaction could not complete. Retry with the same upload attempt.",
    );
  }
  async listAttempts(
    limit: number,
    cursor?: string,
  ): Promise<{ items: Data[]; cursor?: string }> {
    const params = new URLSearchParams({ pageSize: String(limit) });
    if (cursor) params.set("pageToken", cursor);
    const page = await this.request(
      `${this.documentRoot}/proofUploads?${params}`,
    );
    const items = ((page.documents ?? []) as Data[]).map((doc) =>
      Object.fromEntries(
        Object.entries((doc.fields ?? {}) as Record<string, Value>).map((
          [k, v],
        ) => [k, decode(v)]),
      )
    );
    return {
      items,
      cursor: typeof page.nextPageToken === "string"
        ? page.nextPageToken
        : undefined,
    };
  }
}
