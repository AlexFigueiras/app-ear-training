// Edge Function `delete-account`: o próprio usuário exclui a conta e todos os dados.
// Exigência da Google Play (exclusão dentro do app) e direito de eliminação da LGPD (art. 18).
//
// Segurança:
// - O id vem do JWT validado (ctx.userClaims), nunca do corpo da requisição: ninguém apaga a
//   conta de outra pessoa.
// - O cliente admin (chave secreta) só existe aqui no servidor.
// - O app pede a senha de novo antes de chamar (lib/services/account_service.dart).
//
// Os dados clínicos são apagados explicitamente (filhos antes dos pais) e, de novo, pelo
// ON DELETE CASCADE da migration 003 — assim nenhum dado fica órfão mesmo que uma tabela não
// tenha FK para auth.users.
import { withSupabase } from "npm:@supabase/server@1";

// Ordem importa: stimulus_results e rehab_progress referenciam rehab_sessions.
const USER_TABLES = [
  "stimulus_results",
  "rehab_progress",
  "rehab_sessions",
  "audiograms",
  "user_profiles",
  "profiles",
];

// Tabela inexistente neste projeto (schema gerido fora do repo): nada a apagar nela.
const MISSING_TABLE_CODES = new Set(["42P01", "PGRST205"]);

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "method_not_allowed" }, { status: 405 });
    }

    const userId = ctx.userClaims?.id;
    if (!userId) return Response.json({ error: "unauthorized" }, { status: 401 });

    for (const table of USER_TABLES) {
      const { error } = await ctx.supabaseAdmin.from(table).delete().eq("user_id", userId);
      if (error && !MISSING_TABLE_CODES.has(error.code ?? "")) {
        console.error("delete-account: falha ao apagar", table, error.code);
        return Response.json({ error: "delete_failed" }, { status: 500 });
      }
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
    if (error) {
      console.error("delete-account: falha ao apagar usuário", error.message);
      return Response.json({ error: "delete_failed" }, { status: 500 });
    }

    return Response.json({ deleted: true });
  }),
};
