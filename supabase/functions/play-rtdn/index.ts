// Edge Function `play-rtdn`: recebe as notificações em tempo real da Google Play (RTDN, via
// push do Pub/Sub) e ressincroniza a assinatura: renovação, cancelamento, suspensão por falta de
// pagamento e reembolso mudam o plano sem depender de o app ser aberto.
//
// Publicar SEM verificação de JWT (o Pub/Sub não manda token do Supabase):
//   supabase functions deploy play-rtdn --no-verify-jwt
// A autenticação é o segredo na URL do push: .../functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>.
// Passo a passo em docs/PLAY_STORE.md (seção Assinatura).
//
// Respostas: 200 confirma a mensagem (inclusive as ignoradas); 5xx faz o Pub/Sub tentar de novo.
import { withSupabase } from "npm:@supabase/server@1";
import { createPlayApi, PlayApiError, readServiceAccount } from "../_shared/google_play.ts";
import { accountIdFor, parseProductIds, parseRtdnBody } from "../_shared/play_entitlement.ts";
import { supabaseStore, syncPurchase } from "../_shared/subscription_sync.ts";

function sameSecret(received: string, expected: string): boolean {
  const a = new TextEncoder().encode(received);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

function ack(note: string): Response {
  return Response.json({ ok: true, note });
}

export default {
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    if (req.method !== "POST") return Response.json({ error: "method_not_allowed" }, { status: 405 });

    const expected = Deno.env.get("PLAY_RTDN_TOKEN") ?? "";
    if (expected.length < 16) {
      console.error("play-rtdn: secret PLAY_RTDN_TOKEN ausente ou curto");
      return Response.json({ error: "server_misconfigured" }, { status: 500 });
    }
    const received = new URL(req.url).searchParams.get("token") ?? "";
    if (!sameSecret(received, expected)) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return ack("invalid_json");
    }
    const event = parseRtdnBody(body);
    const packageName = Deno.env.get("PLAY_PACKAGE_NAME") ?? "com.bosyn.app";
    if (event === null) return ack("not_rtdn");
    if (event.packageName !== packageName) return ack("other_package");
    if (event.kind === "test") {
      console.log("play-rtdn: notificação de teste recebida");
      return ack("test");
    }
    if (event.purchaseToken === null) return ack("no_subscription_token");

    const store = supabaseStore(ctx.supabaseAdmin);
    try {
      const owner = await store.findOwner(event.purchaseToken);
      // Compra que o app ainda não confirmou: ela será sincronizada quando o app chamar
      // play-subscription (compra nova ou restauração).
      if (owner === null) return ack("unknown_token");

      const play = createPlayApi({
        account: readServiceAccount(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT")),
        packageName,
      });
      const result = await syncPurchase(
        {
          play,
          store,
          allowedProducts: parseProductIds(Deno.env.get("PLAY_SUBSCRIPTION_IDS")),
          now: new Date(),
        },
        { purchaseToken: event.purchaseToken, userId: owner, expectedAccountId: await accountIdFor(owner) },
      );
      if (!result.ok && result.status >= 500) {
        return Response.json({ error: result.error }, { status: 503 });
      }
      return ack(result.ok ? `synced:${result.plan.status}` : `rejected:${result.error}`);
    } catch (error) {
      const misconfigured = error instanceof PlayApiError && error.status === 0;
      console.error("play-rtdn: falha", error instanceof Error ? error.message : error);
      return Response.json(
        { error: misconfigured ? "server_misconfigured" : "sync_failed" },
        { status: misconfigured ? 500 : 503 },
      );
    }
  }),
};
