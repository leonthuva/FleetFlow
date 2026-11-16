import { after, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
const require = createRequire(
  new URL("../tooling/package.json", import.meta.url),
);
const { PGlite } = require("@electric-sql/pglite");
const db = new PGlite();
await db.exec(
  `create role anon;create role authenticated;create role service_role bypassrls;
create schema auth;create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
grant usage on schema auth to anon,authenticated,service_role;grant execute on function auth.jwt() to anon,authenticated,service_role;
create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text not null references storage.buckets(id),name text not null,unique(bucket_id,name));
alter table storage.objects enable row level security;grant usage on schema storage to anon,authenticated,service_role;grant all on all tables in schema storage to anon,authenticated,service_role;
-- An unrelated permissive policy must not open the proof bucket.
create policy legacy_allow_all on storage.objects for all to anon,authenticated using(true) with check(true);`,
);
await db.exec(
  readFileSync(
    new URL(
      "../migrations/202611160001_private_delivery_proofs.sql",
      import.meta.url,
    ),
    "utf8",
  ),
);
after(() => db.close());
const id = "12345678-1234-4234-8234-123456789abc", path = `driver/D1/${id}.png`;
const claims = (uid = "driver", extra = {}) =>
  JSON.stringify({
    sub: uid,
    role: "authenticated",
    iss: "https://securetoken.google.com/fleetflow-dev-29e55",
    aud: "fleetflow-dev-29e55",
    ...extra,
  });
async function as(role, jwt, sql, params = []) {
  await db.exec("begin");
  try {
    await db.query("select set_config('request.jwt.claims',$1,true)", [jwt]);
    await db.exec(`set local role ${role}`);
    const result = await db.query(sql, params);
    await db.exec("commit");
    return result;
  } catch (error) {
    await db.exec("rollback");
    throw error;
  }
}
async function grant(attempt = id, object = path) {
  return as(
    "service_role",
    "{}",
    "select public.fleetflow_put_proof_grant($1::uuid,$2,$3,$4,$5,$6::bigint,$7,$8::timestamptz)",
    [
      attempt,
      "driver",
      "D1",
      object,
      "image/png",
      80,
      "a".repeat(64),
      new Date(Date.now() + 600000).toISOString(),
    ],
  );
}
test("bucket is private with the exact size and MIME allowlist", async () => {
  const result = await db.query(
    "select public,file_size_limit,allowed_mime_types from storage.buckets where id='delivery-proofs'",
  );
  assert.equal(result.rows[0].public, false);
  assert.equal(Number(result.rows[0].file_size_limit), 5000000);
  assert.deepEqual(result.rows[0].allowed_mime_types, [
    "image/jpeg",
    "image/png",
    "image/webp",
  ]);
});
test("anonymous/cross-driver/ungranted uploads denied even with legacy broad policy", async () => {
  await assert.rejects(() =>
    as(
      "anon",
      "{}",
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", path],
    )
  );
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", path],
    )
  );
  await grant();
  await assert.rejects(() =>
    as(
      "authenticated",
      claims("other"),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", path],
    )
  );
});
test("only service role can issue or close trusted grants", async () => {
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "select public.fleetflow_close_proof_grant($1::uuid)",
      [id],
    )
  );
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "select * from fleetflow_private.proof_upload_grants",
    )
  );
});
test("valid driver can insert only the exact authorized path, once", async () => {
  await as(
    "authenticated",
    claims(),
    "insert into storage.objects(bucket_id,name)values($1,$2)",
    ["delivery-proofs", path],
  );
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", path],
    )
  );
  for (
    const badPath of [
      `other/D1/${id}.png`,
      `driver/D2/${id}.png`,
      `driver/D1/${id}.jpg`,
      `driver/../${id}.png`,
    ]
  ) {
    await assert.rejects(() =>
      as(
        "authenticated",
        claims(),
        "insert into storage.objects(bucket_id,name)values($1,$2)",
        ["delivery-proofs", badPath],
      )
    );
  }
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["invalid-bucket", path],
    )
  );
});
test("raw object SELECT, replacement and delete are denied to all clients", async () => {
  const read = await as(
    "authenticated",
    claims(),
    "select * from storage.objects where bucket_id=$1",
    ["delivery-proofs"],
  );
  assert.equal(read.rows.length, 0);
  const managerRead = await as(
    "authenticated",
    claims("manager"),
    "select * from storage.objects where bucket_id=$1",
    ["delivery-proofs"],
  );
  assert.equal(managerRead.rows.length, 0);
  const update = await as(
    "authenticated",
    claims(),
    "update storage.objects set name=$1 where bucket_id=$2 returning *",
    ["replacement.png", "delivery-proofs"],
  );
  assert.equal(update.rows.length, 0);
  const removal = await as(
    "authenticated",
    claims(),
    "delete from storage.objects where bucket_id=$1 returning *",
    ["delivery-proofs"],
  );
  assert.equal(removal.rows.length, 0);
  assert.equal(
    (await db.query("select * from storage.objects")).rows.length,
    1,
  );
});
test("wrong Firebase issuer/audience/role, expired and closed grants cannot upload", async () => {
  const next = "22345678-1234-4234-8234-123456789abc",
    object = `driver/D1/${next}.png`;
  await grant(next, object);
  for (
    const jwt of [
      claims("driver", { iss: "https://attacker" }),
      claims("driver", { aud: "another-project" }),
      claims("driver", { role: "anon" }),
    ]
  ) {
    await assert.rejects(() =>
      as(
        "authenticated",
        jwt,
        "insert into storage.objects(bucket_id,name)values($1,$2)",
        ["delivery-proofs", object],
      )
    );
  }
  await as(
    "service_role",
    "{}",
    "select public.fleetflow_close_proof_grant($1::uuid)",
    [next],
  );
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", object],
    )
  );
  const expired = "32345678-1234-4234-8234-123456789abc",
    expiredPath = `driver/D1/${expired}.png`;
  await grant(expired, expiredPath);
  await db.query(
    "update fleetflow_private.proof_upload_grants set expires_at=now()-interval '1 minute' where attempt_id=$1::uuid",
    [expired],
  );
  await assert.rejects(() =>
    as(
      "authenticated",
      claims(),
      "insert into storage.objects(bucket_id,name)values($1,$2)",
      ["delivery-proofs", expiredPath],
    )
  );
});
test("grant binding is immutable and invalid object names/size/MIME are rejected", async () => {
  await assert.rejects(() =>
    as(
      "service_role",
      "{}",
      "select public.fleetflow_put_proof_grant($1::uuid,$2,$3,$4,$5,$6::bigint,$7,$8::timestamptz)",
      [
        id,
        "other",
        "D1",
        path,
        "image/png",
        80,
        "a".repeat(64),
        new Date(Date.now() + 600000).toISOString(),
      ],
    )
  );
});

test("grant table rejects oversized, empty, unsupported MIME and noncanonical paths", async () => {
  for (
    const [mime, size, object] of [
      ["image/png", 5000001, path],
      ["image/png", 0, path],
      ["text/plain", 80, path],
      ["image/png", 80, "driver/../bad.png"],
    ]
  ) {
    const attempt = crypto.randomUUID(),
      objectPath = object === path ? `driver/D1/${attempt}.png` : object;
    await assert.rejects(() =>
      as(
        "service_role",
        "{}",
        "select public.fleetflow_put_proof_grant($1::uuid,$2,$3,$4,$5,$6::bigint,$7,$8::timestamptz)",
        [
          attempt,
          "driver",
          "D1",
          objectPath,
          mime,
          size,
          "a".repeat(64),
          new Date(Date.now() + 600000).toISOString(),
        ],
      )
    );
  }
});
