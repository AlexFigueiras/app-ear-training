// Sincroniza uma compra da Play com o plano do usuário no banco. Mesmo caminho para a
// confirmação feita pelo app (`play-subscription`) e para as notificações da Play
// (`play-rtdn`): ler a assinatura na Google, gravar o token com o dono, recalcular o plano e
// confirmar (acknowledge) a compra. Testado em subscription_sync_test.ts com fakes.

import type { SupabaseContext } from "npm:@supabase/server@1";
import { type PlayApi, PlayApiError } from "./google_play.ts";
import {
  type Entitlement,
  evaluateSubscription,
  type ProfilePlan,
  profilePlanFrom,
  SUPERSEDED_STATE,
} from "./play_entitlement.ts";

export interface PurchaseRow {
  purchase_token: string;
  user_id: string;
  product_id: string;
  subscription_state: string;
  expires_at: string | null;
  auto_renewing: boolean;
  linked_purchase_token: string | null;
  latest_order_id: string | null;
  test_purchase: boolean;
  updated_at: string;
}

/** Acesso ao banco usado pela sincronização (fake nos testes, Supabase em produção). */
export interface SubscriptionStore {
  findOwner(purchaseToken: string): Promise<string | null>;
  savePurchase(row: PurchaseRow): Promise<void>;
  markSuperseded(purchaseToken: string, userId: string, nowIso: string): Promise<void>;
  listForUser(userId: string): Promise<Array<{ subscription_state: string; expires_at: string | null }>>;
  /** Grava o plano no perfil; nunca mexe em 'elite' (PRO dado à mão). */
  saveProfilePlan(userId: string, plan: ProfilePlan): Promise<void>;
}

export interface SyncDeps {
  play: PlayApi;
  store: SubscriptionStore;
  allowedProducts: ReadonlySet<string>;
  now: Date;
}

export interface SyncInput {
  purchaseToken: string;
  userId: string;
  /** obfuscatedAccountId esperado (accountIdFor(userId)). */
  expectedAccountId: string;
}

export type SyncResult =
  | { ok: true; entitlement: Entitlement; plan: ProfilePlan }
  | { ok: false; status: number; error: string };

export async function syncPurchase(deps: SyncDeps, input: SyncInput): Promise<SyncResult> {
  const owner = await deps.store.findOwner(input.purchaseToken);
  if (owner !== null && owner !== input.userId) {
    return { ok: false, status: 409, error: "purchase_owned_by_other_account" };
  }

  let purchase;
  try {
    purchase = await deps.play.getSubscription(input.purchaseToken);
  } catch (error) {
    if (
      error instanceof PlayApiError && (error.status === 400 || error.status === 404 || error.status === 410)
    ) {
      return { ok: false, status: 400, error: "invalid_purchase_token" };
    }
    console.error("play: falha ao ler a assinatura", error instanceof Error ? error.message : error);
    return { ok: false, status: 502, error: "play_unavailable" };
  }

  const entitlement = evaluateSubscription(purchase, deps.allowedProducts, deps.now);
  if (!entitlement.productAllowed || entitlement.productId === null) {
    return { ok: false, status: 403, error: "product_not_allowed" };
  }
  // Compra feita pelo app leva o id da conta; promoção resgatada direto na loja não leva.
  if (
    entitlement.obfuscatedAccountId !== null && entitlement.obfuscatedAccountId !== input.expectedAccountId
  ) {
    return { ok: false, status: 403, error: "account_mismatch" };
  }

  const nowIso = deps.now.toISOString();
  await deps.store.savePurchase({
    purchase_token: input.purchaseToken,
    user_id: input.userId,
    product_id: entitlement.productId,
    subscription_state: entitlement.state,
    expires_at: entitlement.expiresAt,
    auto_renewing: entitlement.autoRenewing,
    linked_purchase_token: entitlement.linkedPurchaseToken,
    latest_order_id: entitlement.latestOrderId,
    test_purchase: entitlement.testPurchase,
    updated_at: nowIso,
  });
  // Troca de plano ou reassinatura: o token antigo deixa de valer (orientação da Google).
  if (entitlement.linkedPurchaseToken !== null) {
    await deps.store.markSuperseded(entitlement.linkedPurchaseToken, input.userId, nowIso);
  }

  const plan = profilePlanFrom(await deps.store.listForUser(input.userId), deps.now);
  await deps.store.saveProfilePlan(input.userId, plan);

  // Confirma só depois de gravar o plano: se a gravação falhar, a compra não confirmada é
  // reembolsada pela Play em 3 dias em vez de ficar paga sem PRO.
  if (entitlement.needsAcknowledge) {
    try {
      await deps.play.acknowledge(entitlement.productId, input.purchaseToken);
    } catch (error) {
      // O app também confirma (completePurchase) e a próxima sincronização tenta de novo.
      console.error("play: acknowledge falhou", error instanceof Error ? error.message : error);
    }
  }

  return { ok: true, entitlement, plan };
}

function throwOnError(error: { message: string } | null, what: string): void {
  if (error) throw new Error(`${what}: ${error.message}`);
}

/** Implementação real sobre o cliente admin do Supabase (chave secreta, ignora RLS). */
export function supabaseStore(admin: SupabaseContext["supabaseAdmin"]): SubscriptionStore {
  return {
    async findOwner(purchaseToken) {
      const { data, error } = await admin
        .from("play_subscriptions")
        .select("user_id")
        .eq("purchase_token", purchaseToken)
        .maybeSingle();
      throwOnError(error, "play_subscriptions.select");
      return (data?.user_id as string | undefined) ?? null;
    },
    async savePurchase(row) {
      const { error } = await admin.from("play_subscriptions").upsert(row, {
        onConflict: "purchase_token",
      });
      throwOnError(error, "play_subscriptions.upsert");
    },
    async markSuperseded(purchaseToken, userId, nowIso) {
      const { error } = await admin
        .from("play_subscriptions")
        .update({ subscription_state: SUPERSEDED_STATE, updated_at: nowIso })
        .eq("purchase_token", purchaseToken)
        .eq("user_id", userId);
      throwOnError(error, "play_subscriptions.update");
    },
    async listForUser(userId) {
      const { data, error } = await admin
        .from("play_subscriptions")
        .select("subscription_state, expires_at")
        .eq("user_id", userId);
      throwOnError(error, "play_subscriptions.list");
      return (data ?? []) as Array<{ subscription_state: string; expires_at: string | null }>;
    },
    async saveProfilePlan(userId, plan) {
      const { data, error } = await admin
        .from("profiles")
        .select("subscription_status")
        .eq("user_id", userId)
        .maybeSingle();
      throwOnError(error, "profiles.select");
      if (data?.subscription_status === "elite") return;

      const { error: upsertError } = await admin.from("profiles").upsert(
        {
          user_id: userId,
          subscription_status: plan.status,
          subscription_expires_at: plan.expiresAt,
        },
        { onConflict: "user_id" },
      );
      throwOnError(upsertError, "profiles.upsert");
    },
  };
}
