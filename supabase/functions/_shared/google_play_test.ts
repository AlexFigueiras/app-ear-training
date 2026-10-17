import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import {
  createPlayApi,
  PlayApiError,
  readServiceAccount,
  type ServiceAccount,
  signServiceAccountJwt,
} from "./google_play.ts";

async function testAccount(): Promise<{ account: ServiceAccount; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let binary = "";
  for (const byte of der) binary += String.fromCharCode(byte);
  const body = btoa(binary).match(/.{1,64}/g)!.join("\n");
  return {
    account: {
      client_email: "bosyn-play@projeto.iam.gserviceaccount.com",
      private_key: `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----\n`,
    },
    publicKey: pair.publicKey,
  };
}

function decodePart(part: string): Record<string, unknown> {
  const padded = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
  return JSON.parse(atob(padded));
}

function bytesOf(part: string): Uint8Array<ArrayBuffer> {
  const padded = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

Deno.test("JWT da conta de serviço: assinatura RS256 válida e claims do escopo da Play", async () => {
  const { account, publicKey } = await testAccount();
  const jwt = await signServiceAccountJwt(account, 1_700_000_000);
  const [header, claims, signature] = jwt.split(".");

  assertEquals(decodePart(header), { alg: "RS256", typ: "JWT" });
  assertEquals(decodePart(claims), {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: 1_700_000_000,
    exp: 1_700_003_600,
  });
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    bytesOf(signature),
    new TextEncoder().encode(`${header}.${claims}`),
  );
  assert(valid);
});

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}

function fakeFetch(responses: Array<(call: Call) => Response>): { fetchFn: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];
  const fetchFn = ((input: string | URL | Request, init: RequestInit = {}) => {
    const call: Call = {
      url: String(input),
      method: init.method ?? "GET",
      headers: Object.fromEntries(new Headers(init.headers).entries()),
      body: init.body === undefined || init.body === null ? "" : String(init.body),
    };
    calls.push(call);
    const next = responses.shift();
    if (!next) throw new Error(`requisição inesperada: ${call.url}`);
    return Promise.resolve(next(call));
  }) as typeof fetch;
  return { fetchFn, calls };
}

const tokenResponse = () => Response.json({ access_token: "token-oauth-de-teste", expires_in: 3600 });

Deno.test("lê a assinatura pelo token e reaproveita o token OAuth", async () => {
  const { account } = await testAccount();
  const { fetchFn, calls } = fakeFetch([
    tokenResponse,
    () => Response.json({ subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }),
    () => Response.json({ subscriptionState: "SUBSCRIPTION_STATE_CANCELED" }),
  ]);
  const api = createPlayApi({
    account,
    packageName: "com.bosyn.app",
    fetchFn,
    nowMs: () => 1_700_000_000_000,
  });

  assertEquals((await api.getSubscription("tok/en+1")).subscriptionState, "SUBSCRIPTION_STATE_ACTIVE");
  assertEquals((await api.getSubscription("tok2")).subscriptionState, "SUBSCRIPTION_STATE_CANCELED");

  assertEquals(calls.length, 3, "um token OAuth para as duas leituras");
  assertEquals(calls[0].url, "https://oauth2.googleapis.com/token");
  assertEquals(calls[0].method, "POST");
  const form = new URLSearchParams(calls[0].body);
  assertEquals(form.get("grant_type"), "urn:ietf:params:oauth:grant-type:jwt-bearer");
  assertEquals(form.get("assertion")?.split(".").length, 3);
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bosyn.app/purchases/subscriptionsv2/tokens/tok%2Fen%2B1",
  );
  assertEquals(calls[1].headers["authorization"], "Bearer token-oauth-de-teste");
});

Deno.test("token OAuth vencido é renovado", async () => {
  const { account } = await testAccount();
  let now = 1_700_000_000_000;
  const { fetchFn, calls } = fakeFetch([
    tokenResponse,
    () => Response.json({}),
    tokenResponse,
    () => Response.json({}),
  ]);
  const api = createPlayApi({ account, packageName: "com.bosyn.app", fetchFn, nowMs: () => now });
  await api.getSubscription("a");
  now += 3_600_000;
  await api.getSubscription("b");
  assertEquals(calls.filter((c) => c.url.includes("oauth2")).length, 2);
});

Deno.test("confirma a compra no endpoint de acknowledge da assinatura", async () => {
  const { account } = await testAccount();
  const { fetchFn, calls } = fakeFetch([tokenResponse, () => new Response(null, { status: 204 })]);
  const api = createPlayApi({ account, packageName: "com.bosyn.app", fetchFn });
  await api.acknowledge("bosyn_pro_mensal", "tok");
  assertEquals(
    calls[1].url,
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.bosyn.app/purchases/subscriptions/bosyn_pro_mensal/tokens/tok:acknowledge",
  );
  assertEquals(calls[1].method, "POST");
});

Deno.test("erro HTTP da Google vira PlayApiError com o status", async () => {
  const { account } = await testAccount();
  const { fetchFn } = fakeFetch([tokenResponse, () => new Response("{}", { status: 410 })]);
  const api = createPlayApi({ account, packageName: "com.bosyn.app", fetchFn });
  const error = await assertRejects(() => api.getSubscription("velho"), PlayApiError);
  assertEquals(error.status, 410);
});

Deno.test("conta de serviço ausente ou incompleta é erro de configuração (status 0)", () => {
  for (const json of [undefined, "", "não é json", JSON.stringify({ client_email: "x" })]) {
    const error = assertThrows(() => readServiceAccount(json), PlayApiError);
    assertEquals(error.status, 0);
  }
  assertEquals(
    readServiceAccount(JSON.stringify({ client_email: "a@b", private_key: "k", token_uri: "https://t" })),
    { client_email: "a@b", private_key: "k", token_uri: "https://t" },
  );
});
