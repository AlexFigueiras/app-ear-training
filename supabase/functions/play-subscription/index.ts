// Edge Function `play-subscription`: o app manda o token de uma compra do Google Play e o
// servidor decide o plano. Nada do que o app diz sobre a compra é aceito sem a Google confirmar.
//
// Segurança:
// - O usuário vem do JWT validado (ctx.userClaims), nunca do corpo.
// - O token é lido na Google Play Developer API com a conta de serviço (secret
//   GOOGLE_PLAY_SERVICE_ACCOUNT); só produtos de PLAY_SUBSCRIPTION_IDS contam.
// - Um token só libera o PRO para uma conta (tabela play_subscriptions, migration 004).
// - O plano em `profiles` só é gravado aqui e em `play-rtdn`, com a chave secreta.
//
// Contrato com o app (lib/services/billing_service.dart): POST JSON { purchaseToken }
// → 200 { entitled, expiresAt, productId, state } | 4xx/5xx JSON { error }.
import { withSupabase } from "npm:@supabase/server@1";
import { createPlayApi, PlayApiError, readServiceAccount } from "../_shared/google_play.ts";
import { accountIdFor, parseProductIds } from "../_shared/play_entitlement.ts";
import { supabaseStore, syncPurchase } from "../_shared/subscription_sync.ts";

const MAX_TOKEN_LENGTH = 4096;

function errorResponse(error: string, status: number): Response {
  return Response.json({ error }, { status });
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return errorResponse("method_not_allowed", 405);

    const userId = ctx.userClaims?.id;
    if (!userId) return errorResponse("unauthorized", 401);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("invalid_json", 400);
    }
    const purchaseToken = typeof body.purchaseToken === "string" ? body.purchaseToken.trim() : "";
    if (!purchaseToken || purchaseToken.length > MAX_TOKEN_LENGTH) {
      return errorResponse("invalid_purchase_token", 400);
    }

    let play;
    try {
      play = createPlayApi({
        account: readServiceAccount(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT")),
        packageName: Deno.env.get("PLAY_PACKAGE_NAME") ?? "com.bosyn.app",
      });
    } catch (error) {
      console.error("play-subscription:", error instanceof PlayApiError ? error.message : error);
      return errorResponse("server_misconfigured", 500);
    }

    try {
      const result = await syncPurchase(
        {
          play,
          store: supabaseStore(ctx.supabaseAdmin),
          allowedProducts: parseProductIds(Deno.env.get("PLAY_SUBSCRIPTION_IDS")),
          now: new Date(),
        },
        { purchaseToken, userId, expectedAccountId: await accountIdFor(userId) },
      );
      if (!result.ok) return errorResponse(result.error, result.status);

      return Response.json({
        entitled: result.plan.status === "pro",
        expiresAt: result.plan.expiresAt,
        productId: result.entitlement.productId,
        state: result.entitlement.state,
      });
    } catch (error) {
      console.error("play-subscription: falha", error instanceof Error ? error.message : error);
      return errorResponse("sync_failed", 500);
    }
  }),
};
