# RUNBOOK — operação e incidentes

> Criado em estágio inicial (módulo 15 do bootstrap adaptado). Seções sem experiência operacional
> real ficam marcadas `TBD` explicitamente — não preenchidas com suposição.

## 1. Operação

**"Deploy" aqui é publicar um app mobile, não subir um servidor.**

- **Build de release para a Play Store:**
  ```bash
  flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
  ```
  - O build exige `android/key.properties` com a chave de upload; o Gradle recusa o AAB sem
    ela.
  - Guarde `build/debug-info` de cada versão: é o que permite ler stack traces ofuscados.
  - Passo a passo completo (keystore, Play Console, formulários): `docs/PLAY_STORE.md`.
- **Build de debug via CI:** `.github/workflows/ci.yml`, job `build-apk`, roda a cada push em
  `main`/`claude/**`.
  - Usa os secrets `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` (ou o antigo
    `SUPABASE_ANON_KEY`) configurados no GitHub.
  - Sobe o APK como artifact.
- **Verificação de release via CI:** o job `release-check` gera um APK de release descartável e
  falha se uma `.so` 64-bit não estiver alinhada a 16 KB.
- **Variáveis de build:** `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` (ver `.env.example`).
  - Entram por `--dart-define-from-file=.env`.
  - O app valida no boot e mostra uma tela de erro se faltar algo ou se a chave não for
    pública (`lib/core/app_config.dart`).
- **Edge Functions** (`supabase/functions/`): `tts` (proxy do Google TTS) e `delete-account`
  (exclusão de conta).
  - Deploy: `supabase functions deploy <nome> --project-ref <ref>`.
  - Secret da `tts`: `supabase secrets set GOOGLE_TTS_API_KEY=... --project-ref <ref>`.
  - Logs: Supabase → Edge Functions → Logs.
- **Schema/banco:** o schema do Supabase é gerido **fora deste repositório** (console do
  Supabase).
  - Os `.sql` da raiz são aplicados à mão no SQL Editor, em ordem: `supabase_setup.sql`,
    `001`, `002`, `003_security`.
  - A `003_security` é obrigatória antes da publicação e é idempotente.
  - `TBD`: processo formal de migration (ex.: `supabase/migrations/` + CLI).
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

**Pendência real:** os passos 1–2 foram feitos para `SUPABASE_URL`, `SUPABASE_ANON_KEY` e
`GOOGLE_TTS_API_KEY`. Os passos 3–4 (rotação e avaliação de histórico) seguem pendentes de ação
humana.

**Atualização 2026-10-04:** o repositório é **público**, então as chaves são de conhecimento
público. O app não usa mais a chave do Google TTS (ela foi para a Edge Function `tts`), mas a
chave antiga continua válida até ser apagada no Google Cloud. Roteiro de rotação:
`docs/SECURITY_REVIEW.md`, item C1.
