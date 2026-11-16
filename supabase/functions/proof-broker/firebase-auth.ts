import {
  createRemoteJWKSet,
  importPKCS8,
  jwtVerify,
  type JWTVerifyGetKey,
  SignJWT,
} from "jose";
import { ApiError, type Data, type Identity, safeId } from "./types.ts";
const certificates = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);
export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}
export class GoogleCredentials {
  private token?: { value: string; expires: number };
  private pending?: Promise<string>;
  constructor(
    private account: ServiceAccount,
    private fetcher: typeof fetch = fetch,
  ) {}
  tokenForServer(): Promise<string> {
    if (this.token && this.token.expires > Date.now() + 60_000) {
      return Promise.resolve(this.token.value);
    }
    return this.pending ??= this.issue().finally(() => {
      this.pending = undefined;
    });
  }
  private async issue(): Promise<string> {
    const key = await importPKCS8(this.account.private_key, "RS256");
    const assertion = await new SignJWT({
      scope:
        "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit",
    })
      .setProtectedHeader({ alg: "RS256" }).setIssuer(this.account.client_email)
      .setAudience("https://oauth2.googleapis.com/token").setIssuedAt()
      .setExpirationTime("1h").sign(key);
    const response = await this.fetcher("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) {
      throw new ApiError(
        503,
        "server_credentials",
        "Trusted Firebase credentials are unavailable.",
      );
    }
    const data = await response.json();
    if (typeof data.access_token !== "string") {
      throw new ApiError(
        503,
        "server_credentials",
        "Trusted authentication failed.",
      );
    }
    this.token = {
      value: data.access_token,
      expires: Date.now() + Number(data.expires_in ?? 3600) * 1000,
    };
    return this.token.value;
  }
}
export async function verifyFirebaseToken(
  token: string,
  project: string,
  lookup: (uid: string) => Promise<Data | null>,
  keys: JWTVerifyGetKey = certificates,
): Promise<Identity> {
  try {
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ["RS256"],
      issuer: `https://securetoken.google.com/${project}`,
      audience: project,
      requiredClaims: ["exp", "iat", "sub", "auth_time"],
      clockTolerance: 5,
    });
    const uid = safeId(payload.sub, "Firebase UID");
    if (
      payload.role !== "authenticated" || typeof payload.iat !== "number" ||
      payload.iat > Date.now() / 1000 + 5 ||
      typeof payload.auth_time !== "number" ||
      payload.auth_time > Date.now() / 1000 + 5
    ) throw new Error("Invalid Firebase claims");
    const account = await lookup(uid);
    if (
      !account || account.disabled === true ||
      Number(account.validSince ?? 0) > payload.auth_time
    ) throw new Error("Disabled or revoked Firebase account");
    return { uid };
  } catch (e) {
    if (e instanceof ApiError && e.status >= 500) throw e;
    throw new ApiError(
      401,
      "firebase_token_required",
      "A current Firebase ID token with the authenticated claim is required.",
    );
  }
}
export function firebaseAccountLookup(
  project: string,
  credentials: GoogleCredentials,
): (uid: string) => Promise<Data | null> {
  return async (uid) => {
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await credentials.tokenForServer()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ localId: [uid] }),
        signal: AbortSignal.timeout(20_000),
      },
    );
    if (!response.ok) {
      throw new ApiError(
        503,
        "account_lookup",
        "Firebase account status could not be verified.",
      );
    }
    const data = await response.json();
    return data.users?.[0] ?? null;
  };
}
