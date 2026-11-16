import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
const configPath = new URL("../../.env.supabase.public.json", import.meta.url);
const local = existsSync(configPath)
  ? JSON.parse(readFileSync(configPath, "utf8"))
  : {};
const url = process.env.SUPABASE_URL ?? local.SUPABASE_URL,
  key = process.env.SUPABASE_PUBLISHABLE_KEY ?? local.SUPABASE_PUBLISHABLE_KEY;
const reason = !url || !key
  ? "BLOCKED: public Supabase project configuration is missing"
  : false;
const bytes = readFileSync(new URL("./fixtures/proof.png", import.meta.url));
for (const operation of ["upload", "list", "read"]) {
  test(
    operation === "list"
      ? "LIVE anonymous listing discloses no object rows (currently empty bucket)"
      : `LIVE anonymous ${operation} returns no file/success`,
    { skip: reason },
    async () => {
      const path = `qa-anonymous/D1/${randomUUID()}.png`;
      const endpoint = operation === "upload"
        ? `/storage/v1/object/delivery-proofs/${path}`
        : operation === "list"
        ? "/storage/v1/object/list/delivery-proofs"
        : `/storage/v1/object/authenticated/delivery-proofs/${path}`;
      const response = await fetch(url + endpoint, {
        method: operation === "read" ? "GET" : "POST",
        headers: {
          apikey: key,
          ...(operation === "list"
            ? { "Content-Type": "application/json" }
            : { "Content-Type": "image/png" }),
        },
        body: operation === "read"
          ? undefined
          : operation === "list"
          ? JSON.stringify({ prefix: "", limit: 1 })
          : bytes,
        signal: AbortSignal.timeout(20000),
      });
      // Consume the response but never print provider bodies, tokens or private URLs.
      const body = await response.text();
      if (operation === "list" && response.status === 200) {
        assert.deepEqual(JSON.parse(body), []);
      } else {assert.ok(
          [400, 401, 403].includes(response.status),
          `Expected access denial; received HTTP ${response.status}`,
        );}
    },
  );
}
