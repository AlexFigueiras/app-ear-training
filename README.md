# ear_training (BOSYN)

![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)
<!-- Substitua OWNER/REPO pelo caminho real do repositório no GitHub. -->

App Flutter mobile de reabilitação auditiva baseada em plasticidade neural. Aplica audiogramas
clínicos a testes de limiar tonal, discriminação fonêmica, atenção espacial e fala no ruído, com
engine de áudio nativo (C++/Oboe via FFI) para DSP em baixa latência.

> **Se você é uma IA (Claude, Gemini, Cursor, etc.), comece por [`AGENTS.md`](AGENTS.md)** — é a
> fonte única de verdade deste repositório. Leia `docs/STATUS.md` antes de propor ou implementar
> qualquer coisa.

## Setup

```bash
git clone <url-do-repo>
cd app-ear-training
flutter pub get
cp .env.example .env      # preencha SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY (só valores públicos)
git config core.hooksPath .githooks   # ativa os git hooks versionados (ver nota abaixo)
flutter run --dart-define-from-file=.env
```

A configuração entra em tempo de build (`--dart-define-from-file`); o `.env` não é mais
empacotado no app. No VS Code, as configurações de `.vscode/launch.json` já passam o arquivo.
Sem configuração válida o app abre numa tela de erro explícita (fail-fast).

**Nota sobre os git hooks:** diferente de projetos Node (`npm install` ativa hooks
automaticamente via `prepare`), `pub` não tem um mecanismo de lifecycle script equivalente. Rode
`git config core.hooksPath .githooks` manualmente uma vez após o clone — sem isso, o pre-commit e
o commit-msg (Conventional Commits) não são acionados localmente (o CI continua rodando os mesmos
checks de qualquer forma).

## Comandos principais

```bash
flutter run --dart-define-from-file=.env                          # dev
flutter analyze                                                    # lint/análise estática
dart format --output=none --set-exit-if-changed lib test tool      # checar formatação
flutter test                                                        # testes
flutter test --coverage                                             # testes com cobertura
dart tool/verify_rules.dart                                     # verify-rules (tamanho, secrets, config de release)
```

Publicação na Google Play (assinatura, AAB, formulários do Play Console): ver
[`docs/PLAY_STORE.md`](docs/PLAY_STORE.md). Revisão de segurança: [`docs/SECURITY_REVIEW.md`](docs/SECURITY_REVIEW.md).

Não há comando `generate` (scaffolding automático) neste projeto — ver `AGENTS.md` seção 2.

## Backend

Não há banco/servidor local para subir. O backend é o Supabase, gerenciado externamente; o app
fala com ele via `supabase_flutter` usando `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` do `.env`.
O que exige segredo roda em Edge Functions versionadas em [`supabase/functions/`](supabase/functions/)
(`tts`: proxy do Google Text-to-Speech; `delete-account`: exclusão de conta). Mudanças de schema
ficam nos `supabase_migration_*.sql` da raiz, aplicados à mão no SQL Editor.

## Estrutura e governança

- [`AGENTS.md`](AGENTS.md) — fonte única de verdade para agentes de IA (protocolo, leis de
  segurança, padrões de qualidade, comandos).
- [`docs/STATUS.md`](docs/STATUS.md) — o que está pronto, parcial ou a fazer.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) e [`docs/adr/`](docs/adr/) — histórico de decisões.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — topologia atual e topologia-alvo.
- [`docs/RUNBOOK.md`](docs/RUNBOOK.md) — operação, incidentes, rollback.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — fluxo de contribuição.
- [`MASTER-PLAN.md`](MASTER-PLAN.md) — progresso da fundação de governança (bootstrap Dev OS).
- [`#PROJECT_BRAIN.md`](#PROJECT_BRAIN.md) e [`docs/MASTER_PLAN.md`](docs/MASTER_PLAN.md) — visão
  de produto/design (SSOT de produto, não confundir com o `MASTER-PLAN.md` de governança acima).

## Sobre o app (para novos devs)

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)
