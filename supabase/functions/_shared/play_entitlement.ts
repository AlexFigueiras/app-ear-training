// Regras puras da assinatura PRO (sem rede, sem banco): o que a resposta da Google Play
// Developer API (purchases.subscriptionsv2) significa para o plano do usuário.
// Usadas pelas Edge Functions `play-subscription` e `play-rtdn`; testadas em
// play_entitlement_test.ts.

/** Subconjunto de SubscriptionPurchaseV2 que o BOSYN lê. */
export interface SubscriptionPurchaseV2 {
  subscriptionState?: string;
  acknowledgementState?: string;
  linkedPurchaseToken?: string;
  latestOrderId?: string;
  testPurchase?: Record<string, unknown>;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    latestSuccessfulOrderId?: string;
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
  }>;
}

/** Produtos de assinatura vendidos no app (lib/monetization/monetization_config.dart). */
export const DEFAULT_PRODUCT_IDS = ["bosyn_pro_mensal", "bosyn_pro_anual"];

/**
 * Estados em que a pessoa mantém o PRO até `expiryTime`. CANCELED só desliga a renovação: o
 * período pago continua valendo. ON_HOLD, PAUSED, EXPIRED e PENDING não dão acesso.
 */
export const ENTITLED_STATES: ReadonlySet<string> = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

/** Estado gravado no token antigo quando uma troca de plano gera um token novo. */
export const SUPERSEDED_STATE = "SUPERSEDED";

export interface Entitlement {
  entitled: boolean;
  /** Produto permitido com a maior validade, ou o primeiro da compra se nenhum for permitido. */
  productId: string | null;
  productAllowed: boolean;
  expiresAt: string | null;
  state: string;
  autoRenewing: boolean;
  /** Compra nova ainda não confirmada: sem confirmação, a Play reembolsa em 3 dias. */
  needsAcknowledge: boolean;
  testPurchase: boolean;
  linkedPurchaseToken: string | null;
  latestOrderId: string | null;
  obfuscatedAccountId: string | null;
}

export interface ProfilePlan {
  status: "pro" | "free";
  expiresAt: string | null;
}

/** Lista de produtos permitidos a partir de "a,b" (secret PLAY_SUBSCRIPTION_IDS). */
export function parseProductIds(value: string | undefined): Set<string> {
  const ids = (value ?? "").split(",").map((id) => id.trim()).filter((id) => id.length > 0);
  return new Set(ids.length > 0 ? ids : DEFAULT_PRODUCT_IDS);
}

function parseTime(value: string | undefined): Date | null {
  if (!value) return null;
  const time = new Date(value);
  return Number.isNaN(time.getTime()) ? null : time;
}

export function evaluateSubscription(
  purchase: SubscriptionPurchaseV2,
  allowedProducts: ReadonlySet<string>,
  now: Date,
): Entitlement {
  const state = purchase.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
  const items = purchase.lineItems ?? [];

  let chosen: (typeof items)[number] | null = null;
  let chosenExpiry: Date | null = null;
  for (const item of items) {
    if (!item.productId || !allowedProducts.has(item.productId)) continue;
    const expiry = parseTime(item.expiryTime);
    if (chosen === null || (expiry !== null && (chosenExpiry === null || expiry > chosenExpiry))) {
      chosen = item;
      chosenExpiry = expiry;
    }
  }

  const productAllowed = chosen !== null;
  const item = chosen ?? items[0] ?? null;
  const expiry = productAllowed ? chosenExpiry : parseTime(item?.expiryTime);
  const entitled = productAllowed && ENTITLED_STATES.has(state) && expiry !== null && expiry > now;

  return {
    entitled,
    productId: item?.productId ?? null,
    productAllowed,
    expiresAt: expiry?.toISOString() ?? null,
    state,
    autoRenewing: item?.autoRenewingPlan?.autoRenewEnabled === true,
    needsAcknowledge: purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
      (state === "SUBSCRIPTION_STATE_ACTIVE" || state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"),
    testPurchase: purchase.testPurchase !== undefined,
    linkedPurchaseToken: purchase.linkedPurchaseToken ?? null,
    latestOrderId: item?.latestSuccessfulOrderId ?? purchase.latestOrderId ?? null,
    obfuscatedAccountId: purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
  };
}

/**
 * Plano do perfil a partir de todas as compras do usuário: PRO enquanto alguma estiver válida,
 * com a maior validade entre elas.
 */
export function profilePlanFrom(
  purchases: ReadonlyArray<{ subscription_state: string; expires_at: string | null }>,
  now: Date,
): ProfilePlan {
  let latest: Date | null = null;
  for (const purchase of purchases) {
    if (!ENTITLED_STATES.has(purchase.subscription_state)) continue;
    const expiry = parseTime(purchase.expires_at ?? undefined);
    if (expiry !== null && expiry > now && (latest === null || expiry > latest)) latest = expiry;
  }
  return latest === null
    ? { status: "free", expiresAt: null }
    : { status: "pro", expiresAt: latest.toISOString() };
}

/**
 * Identificador da conta enviado à Play na compra (obfuscatedAccountId): SHA-256 do id do
 * usuário em hexadecimal minúsculo, 64 caracteres. O app calcula o mesmo valor
 * (lib/services/billing_service.dart) — a Play não recebe o id real.
 */
export async function accountIdFor(userId: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(userId));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export interface RtdnEvent {
  packageName: string;
  kind: "subscription" | "voided" | "test" | "other";
  purchaseToken: string | null;
  notificationType: number | null;
}

/**
 * Lê a mensagem push do Pub/Sub das notificações em tempo real da Play (RTDN). Devolve null
 * se o corpo não for uma mensagem RTDN.
 */
export function parseRtdnBody(body: unknown): RtdnEvent | null {
  const data = (body as { message?: { data?: unknown } } | null)?.message?.data;
  if (typeof data !== "string") return null;

  let payload: Record<string, unknown>;
  try {
    const json = new TextDecoder().decode(Uint8Array.from(atob(data), (c) => c.charCodeAt(0)));
    payload = JSON.parse(json);
  } catch {
    return null;
  }
  if (typeof payload !== "object" || payload === null) return null;

  const packageName = typeof payload.packageName === "string" ? payload.packageName : "";
  const subscription = payload.subscriptionNotification as
    | { purchaseToken?: unknown; notificationType?: unknown }
    | undefined;
  const voided = payload.voidedPurchaseNotification as
    | { purchaseToken?: unknown; productType?: unknown }
    | undefined;

  if (subscription) {
    return {
      packageName,
      kind: "subscription",
      purchaseToken: typeof subscription.purchaseToken === "string" ? subscription.purchaseToken : null,
      notificationType: typeof subscription.notificationType === "number"
        ? subscription.notificationType
        : null,
    };
  }
  // productType 1 = assinatura; reembolso de produto avulso não existe no BOSYN.
  if (voided && voided.productType === 1) {
    return {
      packageName,
      kind: "voided",
      purchaseToken: typeof voided.purchaseToken === "string" ? voided.purchaseToken : null,
      notificationType: null,
    };
  }
  if (payload.testNotification) {
    return { packageName, kind: "test", purchaseToken: null, notificationType: null };
  }
  return { packageName, kind: "other", purchaseToken: null, notificationType: null };
}
