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
cp .env.example .env      # preencha SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_TTS_API_KEY
git config core.hooksPath .githooks   # ativa os git hooks versionados (ver nota abaixo)
flutter run
```

**Nota sobre os git hooks:** diferente de projetos Node (`npm install` ativa hooks
automaticamente via `prepare`), `pub` não tem um mecanismo de lifecycle script equivalente. Rode
`git config core.hooksPath .githooks` manualmente uma vez após o clone — sem isso, o pre-commit e
o commit-msg (Conventional Commits) não são acionados localmente (o CI continua rodando os mesmos
checks de qualquer forma).

## Comandos principais

```bash
flutter run                                                       # dev
flutter analyze                                                    # lint/análise estática
dart format --output=none --set-exit-if-changed lib test tool      # checar formatação
flutter test                                                        # testes
flutter test --coverage                                             # testes com cobertura
dart tool/verify_rules.dart                                     # verify-rules (tamanho de arquivo, secrets)
```

Não há comando `generate` (scaffolding automático) neste projeto — ver `AGENTS.md` seção 2.

## Backend

Não há banco/servidor local para subir. O backend é o Supabase, gerenciado externamente; o app
fala com ele via `supabase_flutter` usando `SUPABASE_URL`/`SUPABASE_ANON_KEY` do `.env`.

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
