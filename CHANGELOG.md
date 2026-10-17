# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/). Este projeto
segue [Conventional Commits](https://www.conventionalcommits.org/pt-br/) — o `commit-msg` hook
(`.githooks/commit-msg`) valida o formato de cada commit.

> Mantido manualmente por ora. O kit original (`bootstrap/13-governanca.md`) recomenda uma
> ferramenta automática (Changesets/semantic-release/git-cliff); nenhuma foi introduzida neste
> bootstrap para não adicionar dependência de runtime/tooling sem necessidade imediata — ver
> `docs/DECISIONS.md`.

## [Unreleased]

### Added (monetização e publicação — 2026-10-17)
- Assinatura PRO pelo Google Play Billing (`in_app_purchase`, Billing Library 8): planos mensal e
  anual, restauração, conferência de cada compra no servidor (Edge Functions `play-subscription`
  e `play-rtdn`, migration 004).
- Anúncios do AdMob só no plano grátis (`google_mobile_ads`): banner na Home e vídeo premiado
  que libera 1 sessão PRO (2 por dia), não personalizados, com consentimento UMP.
- Folha do PRO com preço, renovação e cancelamento; seção "Seu plano" na conta (gerenciar no
  Google Play, restaurar, privacidade dos anúncios).
- Botões do GitHub "1 - Criar chave de upload" e "2 - Gerar AAB para a Play Store", scripts em
  `tool/play/`, ensaio do AAB e job `edge-functions` no CI.
- Ícone adaptativo do BOSYN, recurso gráfico, ficha da loja, Folha de Respostas, `PROGRESSO.md` e
  `tool/legal_html.dart`.

### Added (prontidão Google Play — 2026-10-04)
- Tela Conta e Privacidade: sair, excluir conta (com reautenticação) e política de privacidade
  dentro do app; Edge Function `delete-account`.
- Consentimento LGPD para dado de saúde no cadastro e aviso de saúde no onboarding.
- Política de privacidade e página de exclusão de conta em `docs/legal/`, que precisam de
  revisão jurídica e dos campos `[PREENCHER]`.
- Edge Function `tts`: proxy autenticado do Google Text-to-Speech.
- `supabase_migration_003_security.sql`: plano decidido só pelo servidor, perfil criado no
  cadastro, cascade na exclusão, RLS canônica.
- Configuração de release Android: pacote `com.bosyn.app`, assinatura por `key.properties`,
  targetSdk 36, 16 KB, backup desligado e config de rede só HTTPS.
- `check-release-config` no `verify_rules` e job de CI `release-check` (R8 + 16 KB).
- `docs/PLAY_STORE.md` e `docs/SECURITY_REVIEW.md`.

### Changed
- Configuração entra por `--dart-define-from-file=.env`, com validação fail-fast no boot.
  `SUPABASE_PUBLISHABLE_KEY` substitui `SUPABASE_ANON_KEY`, que ainda é aceito.
- `supabase_flutter` 2.12 → 2.18 (`publishableKey`).
- Paywall: PRO aparece como "em breve" até integrar o Google Play Billing (substituído em
  2026-10-17 pela folha "assinar ou ver um vídeo").
- Política de privacidade 2026-10-17: AdMob, assinatura e contato contato@bosyn.com.br.

### Removed
- Permissões `RECORD_AUDIO` e `BLUETOOTH_*`, que não eram usadas, e a tela que bloqueava o app
  sem elas.
- Dependências sem uso ou substituídas: `flutter_dotenv`, `flutter_stripe`,
  `permission_handler`, `http`.
- Placeholders "Palavra1/Falsa1" do sorteio de estímulos.

### Fixed
- Telemetria offline de um usuário podia subir na conta de outro no mesmo aparelho.
- Estado de gamificação vazava entre contas.
- 2 erros de `flutter analyze` (`training_dashboard.dart`, `widget_test.dart`).

### Security (2026-10-04)
- Qualquer usuário podia se dar o plano PRO por um UPDATE pelo app. Corrigido no app e no banco
  (a migration precisa ser aplicada).
- A chave do Google TTS saiu do APK.
- Dado clínico fora do logcat em release.
- **Pendente (ação humana):** rotacionar as chaves vazadas no histórico; o repositório é
  público.

### Added (bootstrap Dev OS — 2026-07-18)
- Fundação de governança Dev OS (adaptada de `bootstrap/*.md` para Flutter/Dart): `AGENTS.md`,
  `MASTER-PLAN.md`, `docs/STATUS.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`,
  `tool/verify_rules.dart`, hooks versionados (`.githooks/`), CI endurecido, `CHANGELOG.md`,
  `.github/dependabot.yml`, `README.md`/`CONTRIBUTING.md`/`docs/RUNBOOK.md` reescritos.

### Security
- `.env` removido do índice do git (untracked) e adicionado ao `.gitignore`. Rotação das chaves
  expostas (Supabase, Google TTS) segue pendente — ver `docs/DECISIONS.md`.
