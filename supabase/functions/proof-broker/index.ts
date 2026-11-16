import { ProofBroker } from "./broker.ts";
import {
  firebaseAccountLookup,
  GoogleCredentials,
  type ServiceAccount,
  verifyFirebaseToken,
} from "./firebase-auth.ts";
import { FirestoreRest } from "./firestore.ts";
import { inspectImage } from "./images.ts";
import { SupabasePrivateStorage } from "./storage.ts";
import { ApiError, type Data } from "./types.ts";
const project = "fleetflow-dev-29e55";
let runtime: {
  broker: ProofBroker;
  lookup: ReturnType<typeof firebaseAccountLookup>;
} | undefined;
function configured() {
  if (runtime) return runtime;
  const source = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON"),
    url = Deno.env.get("SUPABASE_URL"),
    serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!source || !url || !serverKey) {
    throw new ApiError(
      503,
      "setup_required",
      "The trusted proof backend is not configured.",
    );
  }
  const account = JSON.parse(source) as ServiceAccount;
  if (
    account.project_id !== project || !account.client_email ||
    !account.private_key
  ) {
    throw new ApiError(
      503,
      "wrong_project",
      "The proof backend Firebase project is misconfigured.",
    );
  }
  const credentials = new GoogleCredentials(account);
  runtime = {
    broker: new ProofBroker({
      db: new FirestoreRest(project, () => credentials.tokenForServer()),
      storage: new SupabasePrivateStorage(url, serverKey),
      inspectImage,
      now: () => new Date(),
    }),
    lookup: firebaseAccountLookup(project, credentials),
  };
  return runtime;
}
export async function handler(request: Request): Promise<Response> {
  const origin = request.headers.get("origin");
  const allowed = (Deno.env.get("APP_ALLOWED_ORIGINS") ?? "").split(",").map(
    (s) => s.trim(),
  ).filter(Boolean);
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin) {
    if (!allowed.includes(origin)) {
      return Response.json({
        error: { code: "origin_denied", message: "Origin is not approved." },
      }, { status: 403, headers });
    }
    headers["Access-Control-Allow-Origin"] = origin;
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") {
    return Response.json({
      error: { code: "method_not_allowed", message: "POST is required." },
    }, { status: 405, headers });
  }
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) {
      throw new ApiError(
        401,
        "firebase_token_required",
        "Firebase authentication is required.",
      );
    }
    if (Number(request.headers.get("content-length") ?? 0) > 8192) {
      throw new ApiError(
        413,
        "request_too_large",
        "Proof metadata must be at most 8 KB.",
      );
    }
    const reader = request.body?.getReader();
    let raw = "";
    let size = 0;
    const decoder = new TextDecoder();
    if (reader) {
      try {
        while (true) {
          const part = await reader.read();
          if (part.done) break;
          size += part.value.length;
          if (size > 8192) {
            await reader.cancel();
            throw new ApiError(
              413,
              "request_too_large",
              "Proof metadata must be at most 8 KB.",
            );
          }
          raw += decoder.decode(part.value, { stream: true });
        }
        raw += decoder.decode();
      } finally {
        reader.releaseLock();
      }
    }
    let body: Data;
    try {
      body = JSON.parse(raw);
    } catch {
      throw new ApiError(400, "invalid_json", "Valid JSON is required.");
    }
    const { broker, lookup } = configured();
    const identity = await verifyFirebaseToken(
      authorization.slice(7),
      project,
      lookup,
    );
    return Response.json(await broker.execute(identity, body), {
      status: 200,
      headers,
    });
  } catch (error) {
    const known = error instanceof ApiError ? error : new ApiError(
      503,
      "proof_service_unavailable",
      "Proof processing is temporarily unavailable. Retry with the same photo.",
    );
    // Never log JWTs, private keys, signed URLs or raw provider errors.
    return Response.json({
      error: { code: known.code, message: known.message },
    }, { status: known.status, headers });
  }
}
if (import.meta.main) Deno.serve(handler);
