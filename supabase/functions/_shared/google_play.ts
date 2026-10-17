// Cliente mínimo da Google Play Developer API para as Edge Functions de assinatura.
// Autentica com a conta de serviço (JWT RS256 → token OAuth) e só usa dois endpoints:
// ler a assinatura pelo token de compra e confirmar (acknowledge) a compra.
// Sem SDK do Google: fetch + Web Crypto. Testado em google_play_test.ts.

import type { SubscriptionPurchaseV2 } from "./play_entitlement.ts";

const SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";
const API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

/** Campos usados do JSON da conta de serviço (secret GOOGLE_PLAY_SERVICE_ACCOUNT). */
export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface PlayApi {
  getSubscription(purchaseToken: string): Promise<SubscriptionPurchaseV2>;
  acknowledge(productId: string, purchaseToken: string): Promise<void>;
}

/** Erro HTTP da Google (status da resposta) ou de configuração (status 0). */
export class PlayApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
    this.name = "PlayApiError";
  }
}

/** Lê e valida o JSON da conta de serviço; erro de configuração vira PlayApiError(status 0). */
export function readServiceAccount(json: string | undefined): ServiceAccount {
  if (!json) throw new PlayApiError("GOOGLE_PLAY_SERVICE_ACCOUNT ausente", 0);
  let parsed: Partial<ServiceAccount>;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new PlayApiError("GOOGLE_PLAY_SERVICE_ACCOUNT não é JSON", 0);
  }
  if (typeof parsed.client_email !== "string" || typeof parsed.private_key !== "string") {
    throw new PlayApiError("GOOGLE_PLAY_SERVICE_ACCOUNT sem client_email/private_key", 0);
  }
  return {
    client_email: parsed.client_email,
    private_key: parsed.private_key,
    token_uri: parsed.token_uri,
  };
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----BEGIN [A-Z ]+-----/, "")
    .replace(/-----END [A-Z ]+-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const der = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) der[i] = binary.charCodeAt(i);
  return der;
}

/** JWT assinado que a conta de serviço troca por um token de acesso (fluxo jwt-bearer). */
export async function signServiceAccountJwt(
  account: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(encoder.encode(JSON.stringify({
    iss: account.client_email,
    scope: SCOPE,
    aud: account.token_uri ?? DEFAULT_TOKEN_URI,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  })));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
}

export interface PlayApiOptions {
  account: ServiceAccount;
  packageName: string;
  fetchFn?: typeof fetch;
  nowMs?: () => number;
}

export function createPlayApi(options: PlayApiOptions): PlayApi {
  const fetchFn = options.fetchFn ?? fetch;
  const nowMs = options.nowMs ?? Date.now;
  const base = `${API}/${encodeURIComponent(options.packageName)}/purchases`;
  let cached: { token: string; expiresAtMs: number } | null = null;

  async function accessToken(): Promise<string> {
    if (cached && cached.expiresAtMs - 60_000 > nowMs()) return cached.token;
    const assertion = await signServiceAccountJwt(options.account, Math.floor(nowMs() / 1000));
    const response = await fetchFn(options.account.token_uri ?? DEFAULT_TOKEN_URI, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!response.ok) throw new PlayApiError("token OAuth recusado", response.status);
    const body = await response.json();
    if (typeof body.access_token !== "string") {
      throw new PlayApiError("resposta OAuth sem access_token", 502);
    }
    const lifetimeSeconds = typeof body.expires_in === "number" ? body.expires_in : 3600;
    cached = { token: body.access_token, expiresAtMs: nowMs() + lifetimeSeconds * 1000 };
    return cached.token;
  }

  async function call(url: string, init: RequestInit = {}): Promise<Response> {
    const response = await fetchFn(url, {
      ...init,
      headers: { ...init.headers, Authorization: `Bearer ${await accessToken()}` },
    });
    if (!response.ok) throw new PlayApiError(`Play API respondeu ${response.status}`, response.status);
    return response;
  }

  return {
    async getSubscription(purchaseToken) {
      const response = await call(
        `${base}/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
      );
      return await response.json();
    },
    async acknowledge(productId, purchaseToken) {
      await call(
        `${base}/subscriptions/${encodeURIComponent(productId)}/tokens/${
          encodeURIComponent(purchaseToken)
        }:acknowledge`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" },
      );
    },
  };
}
