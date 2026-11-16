import { strict as a } from "node:assert";
import { handler } from "../functions/proof-broker/index.ts";
Deno.test("HTTP broker rejects unauthenticated requests and unsupported methods without server secrets", async () => {
  a.equal(
    (await handler(
      new Request("https://example.test", { method: "POST", body: "{}" }),
    )).status,
    401,
  );
  a.equal((await handler(new Request("https://example.test"))).status, 405);
  a.equal(
    (await handler(new Request("https://example.test", { method: "OPTIONS" })))
      .status,
    204,
  );
});
Deno.test("HTTP broker rejects unapproved web origins, bad JSON and oversized streaming metadata", async () => {
  a.equal(
    (await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Origin: "https://attacker.test" },
        body: "{}",
      }),
    )).status,
    403,
  );
  a.equal(
    (await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
        body: "not-json",
      }),
    )).status,
    400,
  );
  a.equal(
    (await handler(
      new Request("https://example.test", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
        body: "x".repeat(9000),
      }),
    )).status,
    413,
  );
});
