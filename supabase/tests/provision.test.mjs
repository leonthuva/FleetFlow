import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mergeSupabaseClaim,
  provision,
} from "../scripts/provision-firebase-claims.mjs";
test("claim provisioning preserves all unrelated claims and rejects conflicting role", () => {
  assert.deepEqual(mergeSupabaseClaim({ team: "fleet", admin: false }), {
    team: "fleet",
    admin: false,
    role: "authenticated",
  });
  assert.throws(() => mergeSupabaseClaim({ role: "admin" }));
});
test("provisioning is UID-scoped, role-checked and dry-run by default", async () => {
  let writes = 0;
  const auth = {
    getUser: async () => ({ customClaims: { team: "fleet" } }),
    setCustomUserClaims: async () => {
      writes++;
    },
  };
  const firestore = {
    doc: () => ({ get: async () => ({ data: () => ({ role: "driver" }) }) }),
  };
  await provision("driver", { auth, firestore });
  assert.equal(writes, 0);
  await provision("driver", { apply: true, auth, firestore });
  assert.equal(writes, 1);
});
