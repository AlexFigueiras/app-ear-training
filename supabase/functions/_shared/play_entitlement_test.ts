import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  accountIdFor,
  evaluateSubscription,
  parseProductIds,
  parseRtdnBody,
  profilePlanFrom,
  type SubscriptionPurchaseV2,
} from "./play_entitlement.ts";

const NOW = new Date("2026-10-17T12:00:00Z");
const ALLOWED = new Set(["bosyn_pro_mensal", "bosyn_pro_anual"]);

function purchase(overrides: Partial<SubscriptionPurchaseV2> = {}): SubscriptionPurchaseV2 {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [{
      productId: "bosyn_pro_mensal",
      expiryTime: "2026-11-17T12:00:00Z",
      latestSuccessfulOrderId: "GPA.1",
      autoRenewingPlan: { autoRenewEnabled: true },
    }],
    ...overrides,
  };
}

Deno.test("assinatura ativa e no prazo libera o PRO", () => {
  const result = evaluateSubscription(purchase(), ALLOWED, NOW);
  assertEquals(result.entitled, true);
  assertEquals(result.productId, "bosyn_pro_mensal");
  assertEquals(result.expiresAt, "2026-11-17T12:00:00.000Z");
  assertEquals(result.autoRenewing, true);
  assertEquals(result.needsAcknowledge, false);
  assertEquals(result.latestOrderId, "GPA.1");
});

Deno.test("compra nova sem confirmação pede acknowledge", () => {
  const result = evaluateSubscription(
    purchase({ acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" }),
    ALLOWED,
    NOW,
  );
  assertEquals(result.needsAcknowledge, true);
});

Deno.test("cancelada mantém o PRO até o fim do período pago", () => {
  const canceled = purchase({
    subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
    lineItems: [{ productId: "bosyn_pro_anual", expiryTime: "2026-12-01T00:00:00Z" }],
  });
  const during = evaluateSubscription(canceled, ALLOWED, NOW);
  assertEquals(during.entitled, true);
  assertEquals(during.autoRenewing, false);

  const after = evaluateSubscription(canceled, ALLOWED, new Date("2026-12-02T00:00:00Z"));
  assertEquals(after.entitled, false);
});

Deno.test("período de carência libera; suspensão, pausa, expirada e pendente não", () => {
  const states: Array<[string, boolean]> = [
    ["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", true],
    ["SUBSCRIPTION_STATE_ON_HOLD", false],
    ["SUBSCRIPTION_STATE_PAUSED", false],
    ["SUBSCRIPTION_STATE_EXPIRED", false],
    ["SUBSCRIPTION_STATE_PENDING", false],
    ["SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED", false],
    ["SUBSCRIPTION_STATE_UNSPECIFIED", false],
  ];
  for (const [state, entitled] of states) {
    const result = evaluateSubscription(purchase({ subscriptionState: state }), ALLOWED, NOW);
    assertEquals(result.entitled, entitled, state);
  }
});

Deno.test("produto fora da lista não libera nada", () => {
  const result = evaluateSubscription(
    purchase({ lineItems: [{ productId: "outro_app", expiryTime: "2027-01-01T00:00:00Z" }] }),
    ALLOWED,
    NOW,
  );
  assertEquals(result.entitled, false);
  assertEquals(result.productAllowed, false);
  assertEquals(result.productId, "outro_app");
});

Deno.test("com vários itens, vale o produto permitido de maior validade", () => {
  const result = evaluateSubscription(
    purchase({
      lineItems: [
        { productId: "bosyn_pro_mensal", expiryTime: "2026-11-01T00:00:00Z" },
        { productId: "outro_app", expiryTime: "2030-01-01T00:00:00Z" },
        { productId: "bosyn_pro_anual", expiryTime: "2027-10-01T00:00:00Z" },
      ],
    }),
    ALLOWED,
    NOW,
  );
  assertEquals(result.productId, "bosyn_pro_anual");
  assertEquals(result.expiresAt, "2027-10-01T00:00:00.000Z");
});

Deno.test("sem data de validade não há PRO", () => {
  const result = evaluateSubscription(
    purchase({ lineItems: [{ productId: "bosyn_pro_mensal" }] }),
    ALLOWED,
    NOW,
  );
  assertEquals(result.entitled, false);
  assertEquals(result.expiresAt, null);
});

Deno.test("marca compra de testador e lê o id da conta e o token antigo", () => {
  const result = evaluateSubscription(
    purchase({
      testPurchase: {},
      linkedPurchaseToken: "token-antigo",
      externalAccountIdentifiers: { obfuscatedExternalAccountId: "abc" },
    }),
    ALLOWED,
    NOW,
  );
  assertEquals(result.testPurchase, true);
  assertEquals(result.linkedPurchaseToken, "token-antigo");
  assertEquals(result.obfuscatedAccountId, "abc");
});

Deno.test("plano do perfil: PRO com a maior validade entre compras válidas", () => {
  const plan = profilePlanFrom([
    { subscription_state: "SUBSCRIPTION_STATE_ACTIVE", expires_at: "2026-11-17T12:00:00Z" },
    { subscription_state: "SUPERSEDED", expires_at: "2027-12-01T00:00:00Z" },
    { subscription_state: "SUBSCRIPTION_STATE_CANCELED", expires_at: "2026-12-20T00:00:00Z" },
    { subscription_state: "SUBSCRIPTION_STATE_ACTIVE", expires_at: "2026-10-01T00:00:00Z" },
  ], NOW);
  assertEquals(plan, { status: "pro", expiresAt: "2026-12-20T00:00:00.000Z" });
});

Deno.test("plano do perfil: sem compra válida volta para grátis", () => {
  assertEquals(profilePlanFrom([], NOW), { status: "free", expiresAt: null });
  assertEquals(
    profilePlanFrom([{
      subscription_state: "SUBSCRIPTION_STATE_EXPIRED",
      expires_at: "2027-01-01T00:00:00Z",
    }], NOW),
    { status: "free", expiresAt: null },
  );
});

Deno.test("id da conta é o SHA-256 em hexadecimal (mesmo valor que o app calcula)", async () => {
  assertEquals(
    await accountIdFor("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
  assertEquals((await accountIdFor("2b1f0c8e-0000-4000-8000-000000000000")).length, 64);
});

Deno.test("lista de produtos vem do secret ou cai no padrão", () => {
  assertEquals([...parseProductIds(undefined)], ["bosyn_pro_mensal", "bosyn_pro_anual"]);
  assertEquals([...parseProductIds(" a , b ,, ")], ["a", "b"]);
});

function pubsub(payload: unknown): unknown {
  return { message: { data: btoa(JSON.stringify(payload)), messageId: "1" } };
}

Deno.test("RTDN: lê notificação de assinatura, reembolso e teste", () => {
  assertEquals(
    parseRtdnBody(pubsub({
      packageName: "com.bosyn.app",
      subscriptionNotification: {
        notificationType: 2,
        purchaseToken: "tok",
        subscriptionId: "bosyn_pro_mensal",
      },
    })),
    { packageName: "com.bosyn.app", kind: "subscription", purchaseToken: "tok", notificationType: 2 },
  );
  assertEquals(
    parseRtdnBody(pubsub({
      packageName: "com.bosyn.app",
      voidedPurchaseNotification: { purchaseToken: "tok2", orderId: "GPA.2", productType: 1 },
    }))?.kind,
    "voided",
  );
  assertEquals(
    parseRtdnBody(pubsub({ packageName: "com.bosyn.app", testNotification: { version: "1.0" } }))?.kind,
    "test",
  );
  assertEquals(
    parseRtdnBody(
      pubsub({
        packageName: "com.bosyn.app",
        voidedPurchaseNotification: { purchaseToken: "x", productType: 2 },
      }),
    )?.kind,
    "other",
  );
});

Deno.test("RTDN: corpo que não é mensagem do Pub/Sub é ignorado", () => {
  assertEquals(parseRtdnBody(null), null);
  assertEquals(parseRtdnBody({}), null);
  assertEquals(parseRtdnBody({ message: { data: "%%%não-é-base64" } }), null);
  const notJson = parseRtdnBody({ message: { data: btoa("texto") } });
  assert(notJson === null);
});
