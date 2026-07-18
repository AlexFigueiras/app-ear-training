# RUNBOOK — operação e incidentes

> Criado em estágio inicial (módulo 15 do bootstrap adaptado). Seções sem experiência operacional
> real ficam marcadas `TBD` explicitamente — não preenchidas com suposição.

## 1. Operação

**"Deploy" aqui é publicar um app mobile, não subir um servidor.**

- **Build de release:** `flutter build apk --release` (Android) ou `flutter build appbundle
  --release` para a Play Store. `TBD`: processo de assinatura (keystore) e publicação na Play
  Console — não documentado ainda.
- **Build de debug via CI:** `.github/workflows/ci.yml`, job `build-apk`, roda a cada push em
  `main`/`claude/**`, usa os secrets `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`GOOGLE_TTS_API_KEY`
  configurados no GitHub (Settings → Secrets), sobe o APK como artifact.
- **Variáveis exigidas em runtime:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_TTS_API_KEY`
  (ver `.env.example`). Não há validação fail-fast dessas vars no boot ainda — módulo 04 em
  `MASTER-PLAN.md`, adiado.
- **Schema/banco:** o schema do Supabase é gerido **fora deste repositório** (console do
  Supabase). Os `.sql` na raiz (`supabase_migration_001.sql`, `supabase_migration_002.sql`,
  `supabase_setup.sql`) são histórico de setup manual, não migrations aplicadas automaticamente
  em deploy. `TBD`: processo formal de migration.
- **Plataformas com build configurado:** Android, Web, Windows (`android/`, `web/`, `windows/`).
  iOS/macOS/Linux não estão configurados neste repo.

## 2. Incidentes

- **Logs estruturados / trace IDs:** `TBD` — não existem ainda. O app usa `print`/`debugPrint` ad
  hoc (29 ocorrências em `lib/`, ver `docs/STATUS.md`). Módulo 05 (logger estruturado) ficou
  como item follow-up, não implementado neste bootstrap.
- **Trilha de auditoria:** `TBD` — não existe um mecanismo de audit trail dedicado. Telemetria de
  sessões de treino vai para o Supabase via `lib/services/event_buffer.dart` e
  `lib/services/supabase_service.dart` — consulte o painel do Supabase (tabela de sessões) para
  reconstruir o que aconteceu numa sessão de um paciente.
- **Health endpoints:** N/A — não há servidor próprio neste repositório para expor `/health`.
- **Como investigar um bug relatado por um usuário hoje:**
  1. Reproduzir localmente com `flutter run` usando os mesmos dados de audiograma, se possível.
  2. Checar o console do Supabase (Auth logs, Database logs, API logs) para a janela de tempo.
  3. Checar o painel do Google Cloud para erros da API de TTS, se o bug envolver fala.
  4. Sem logging estruturado, a reconstrução depende de reproduzir + inspecionar estado no
     device (dá para usar `flutter logs`/DevTools).
- **Rollback:** reverter para o build/APK anterior (artifact do CI ou release anterior na Play
  Console). Não há rollback de schema automatizado — mudanças de schema no Supabase são manuais e
  devem ser revertidas manualmente com o mesmo cuidado descrito em `AGENTS.md` seção 2, item 5.

## 3. Incidente de segurança conhecido: segredo exposto no git

Ocorrido antes deste bootstrap, parcialmente mitigado (ver `docs/DECISIONS.md`,
[2026-07-18] Higiene de segredo). Procedimento caso se repita:

1. Remover o `.env`/arquivo com segredo do índice do git: `git rm --cached <arquivo>`.
2. Adicionar ao `.gitignore`.
3. **Rotacionar a chave/credencial exposta** no provedor (Supabase → Settings → API; Google
   Cloud → Credentials). Chaves antigas continuam válidas até serem revogadas — untrack do git
   não invalida a chave.
4. Avaliar se vale reescrever o histórico do git para remover o segredo de commits antigos
   (`git filter-repo` ou BFG) — operação destrutiva, decisão humana, nunca automática.
5. Registrar o incidente em `docs/DECISIONS.md`.

**Pendência real desta rodada:** os passos 1–2 foram feitos para `SUPABASE_URL`,
`SUPABASE_ANON_KEY` e `GOOGLE_TTS_API_KEY`; os passos 3–4 (rotação e avaliação de histórico)
seguem pendentes de ação humana.
