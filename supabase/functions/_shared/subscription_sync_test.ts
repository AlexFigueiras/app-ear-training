import { assertEquals } from "jsr:@std/assert@1";
import { type PlayApi, PlayApiError } from "./google_play.ts";
import type { ProfilePlan, SubscriptionPurchaseV2 } from "./play_entitlement.ts";
import { type PurchaseRow, type SubscriptionStore, syncPurchase } from "./subscription_sync.ts";

const NOW = new Date("2026-10-17T12:00:00Z");
const ALLOWED = new Set(["bosyn_pro_mensal", "bosyn_pro_anual"]);
const USER = "user-a";
const ACCOUNT = "conta-a";

class FakeStore implements SubscriptionStore {
  rows = new Map<string, PurchaseRow>();
  plans = new Map<string, ProfilePlan>();

  findOwner(token: string) {
    return Promise.resolve(this.rows.get(token)?.user_id ?? null);
  }
  savePurchase(row: PurchaseRow) {
    this.rows.set(row.purchase_token, row);
    return Promise.resolve();
  }
  markSuperseded(token: string, userId: string, nowIso: string) {
    const row = this.rows.get(token);
    if (row && row.user_id === userId) {
      this.rows.set(token, { ...row, subscription_state: "SUPERSEDED", updated_at: nowIso });
    }
    return Promise.resolve();
  }
  listForUser(userId: string) {
    return Promise.resolve([...this.rows.values()].filter((row) => row.user_id === userId));
  }
  saveProfilePlan(userId: string, plan: ProfilePlan) {
    this.plans.set(userId, plan);
    return Promise.resolve();
  }
}

class FakePlay implements PlayApi {
  acknowledged: string[] = [];
  reads = 0;
  constructor(
    private readonly respond: (token: string) => SubscriptionPurchaseV2,
    private readonly ackError: Error | null = null,
  ) {}
  getSubscription(token: string) {
    this.reads++;
    try {
      return Promise.resolve(this.respond(token));
    } catch (error) {
      return Promise.reject(error);
    }
  }
  acknowledge(productId: string, token: string) {
    if (this.ackError) return Promise.reject(this.ackError);
    this.acknowledged.push(`${productId}:${token}`);
    return Promise.resolve();
  }
}

function active(overrides: Partial<SubscriptionPurchaseV2> = {}): SubscriptionPurchaseV2 {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    externalAccountIdentifiers: { obfuscatedExternalAccountId: ACCOUNT },
    lineItems: [{ productId: "bosyn_pro_mensal", expiryTime: "2026-11-17T12:00:00Z" }],
    ...overrides,
  };
}

function run(play: PlayApi, store: SubscriptionStore, token = "tok-1", userId = USER) {
  return syncPurchase(
    { play, store, allowedProducts: ALLOWED, now: NOW },
    { purchaseToken: token, userId, expectedAccountId: ACCOUNT },
  );
}

Deno.test("compra nova: grava o token, libera o PRO e confirma uma vez", async () => {
  const store = new FakeStore();
  const play = new FakePlay(() => active());
  const result = await run(play, store);

  assertEquals(result.ok, true);
  assertEquals(store.rows.get("tok-1")?.user_id, USER);
  assertEquals(store.plans.get(USER), { status: "pro", expiresAt: "2026-11-17T12:00:00.000Z" });
  assertEquals(play.acknowledged, ["bosyn_pro_mensal:tok-1"]);
});

Deno.test("token de outra conta não libera nada e nem consulta a Google", async () => {
  const store = new FakeStore();
  await run(new FakePlay(() => active()), store, "tok-1", "user-b");
  const play = new FakePlay(() => active());
  const result = await run(play, store, "tok-1", USER);

  assertEquals(result, { ok: false, status: 409, error: "purchase_owned_by_other_account" });
  assertEquals(play.reads, 0);
  assertEquals(store.plans.has(USER), false);
});

Deno.test("produto de fora não grava nada", async () => {
  const store = new FakeStore();
  const result = await run(
    new FakePlay(() => active({ lineItems: [{ productId: "outro", expiryTime: "2027-01-01T00:00:00Z" }] })),
    store,
  );
  assertEquals(result, { ok: false, status: 403, error: "product_not_allowed" });
  assertEquals(store.rows.size, 0);
});

Deno.test("compra feita com outra conta do app é recusada", async () => {
  const store = new FakeStore();
  const result = await run(
    new FakePlay(() => active({ externalAccountIdentifiers: { obfuscatedExternalAccountId: "conta-b" } })),
    store,
  );
  assertEquals(result, { ok: false, status: 403, error: "account_mismatch" });
  assertEquals(store.rows.size, 0);
});

Deno.test("compra sem id de conta (promoção resgatada na loja) é aceita", async () => {
  const store = new FakeStore();
  const result = await run(new FakePlay(() => active({ externalAccountIdentifiers: undefined })), store);
  assertEquals(result.ok, true);
});

Deno.test("troca de plano: token antigo vira SUPERSEDED e o plano segue o novo", async () => {
  const store = new FakeStore();
  await run(new FakePlay(() => active()), store, "tok-mensal");
  const result = await run(
    new FakePlay(() =>
      active({
        linkedPurchaseToken: "tok-mensal",
        lineItems: [{ productId: "bosyn_pro_anual", expiryTime: "2027-10-17T12:00:00Z" }],
      })
    ),
    store,
    "tok-anual",
  );

  assertEquals(result.ok, true);
  assertEquals(store.rows.get("tok-mensal")?.subscription_state, "SUPERSEDED");
  assertEquals(store.plans.get(USER), { status: "pro", expiresAt: "2027-10-17T12:00:00.000Z" });
});

Deno.test("assinatura expirada (ex.: reembolso) volta o perfil para grátis", async () => {
  const store = new FakeStore();
  await run(new FakePlay(() => active()), store);
  const result = await run(
    new FakePlay(() =>
      active({
        subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
        acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      })
    ),
    store,
  );
  assertEquals(result.ok, true);
  assertEquals(store.plans.get(USER), { status: "free", expiresAt: null });
});

Deno.test("token inválido na Google é erro do pedido; Google fora do ar é 502", async () => {
  const invalid = await run(
    new FakePlay(() => {
      throw new PlayApiError("gone", 410);
    }),
    new FakeStore(),
  );
  assertEquals(invalid, { ok: false, status: 400, error: "invalid_purchase_token" });

  const down = await run(
    new FakePlay(() => {
      throw new PlayApiError("boom", 500);
    }),
    new FakeStore(),
  );
  assertEquals(down, { ok: false, status: 502, error: "play_unavailable" });
});

Deno.test("falha no acknowledge não desfaz o PRO já gravado", async () => {
  const store = new FakeStore();
  const result = await run(new FakePlay(() => active(), new Error("ack falhou")), store);
  assertEquals(result.ok, true);
  assertEquals(store.plans.get(USER)?.status, "pro");
});
