import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
const require = createRequire(
  new URL("../tooling/package.json", import.meta.url),
);
export function mergeSupabaseClaim(existing = {}) {
  if (existing.role !== undefined && existing.role !== "authenticated") {
    throw new Error(
      "Existing role claim conflicts. Review its migration explicitly; no claims were changed.",
    );
  }
  return { ...existing, role: "authenticated" };
}
export async function provision(uid, { apply = false, auth, firestore } = {}) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
    throw new Error("An explicit valid Firebase UID is required.");
  }
  const role = (await firestore.doc(`users/${uid}`).get()).data()?.role;
  if (!["admin", "dispatcher", "driver"].includes(role)) {
    throw new Error("UID has no authoritative approved FleetFlow role.");
  }
  const account = await auth.getUser(uid);
  if (account.disabled) {
    throw new Error("Disabled accounts cannot be provisioned.");
  }
  const claims = mergeSupabaseClaim(account.customClaims ?? {});
  if (apply) await auth.setCustomUserClaims(uid, claims);
  return {
    uid,
    applicationRole: role,
    changed: apply,
    action: apply ? "applied" : "dry-run",
  };
}
if (
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    const args = process.argv.slice(2), uid = args[args.indexOf("--uid") + 1];
    if (!args.includes("--uid") || !uid) {
      throw new Error(
        "Usage: node provision-firebase-claims.mjs --uid FIREBASE_UID [--apply]. Defaults to dry-run; use Application Default Credentials outside this repository.",
      );
    }
    const { initializeApp, applicationDefault } = require("firebase-admin/app");
    const { getAuth } = require("firebase-admin/auth");
    const { getFirestore } = require("firebase-admin/firestore");
    const app = initializeApp({
      credential: applicationDefault(),
      projectId: "fleetflow-dev-29e55",
    });
    console.log(
      JSON.stringify(
        await provision(uid, {
          apply: args.includes("--apply"),
          auth: getAuth(app),
          firestore: getFirestore(app),
        }),
      ),
    );
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
