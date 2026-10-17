# MASTER-PLAN — progresso do bootstrap Dev OS (adaptado a Flutter/Dart)

> Rastreia o estado do PRÓPRIO bootstrap. Um agente que retoma o trabalho lê isto primeiro.
> Legenda: ✅ concluído e verificado · 🟡 em andamento / parcial (pendência explícita) · ⬜ a fazer · 🚫 não aplicável a este projeto
> Regra: nenhum módulo inicia antes de o anterior estar ✅ (verificação de aceite executada).
>
> Este MASTER-PLAN não segue o kit `bootstrap/*.md` ao pé da letra. O kit original assume um
> produto web/SaaS multi-tenant em Node+TypeScript+Postgres com server actions. Este projeto é
> um app Flutter mobile client-only com engine de áudio nativo em C++/FFI, sem backend próprio
> no repositório (Supabase é consumido só como BaaS pelo cliente) e sem multi-tenancy. A tradução
> módulo a módulo está registrada em `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`; cada linha abaixo
> aponta o veredito daquele documento entre parênteses.

## Parâmetros do projeto

```yaml
project_name:            "ear_training (BOSYN — app de treino auditivo)"
description: >
  App Flutter mobile de treino auditivo (não é dispositivo médico): teste de audição como
  triagem relativa, treinos de palavras parecidas, fala no ruído e voz/ruído em lados
  diferentes, e medida de progresso por dígitos no ruído, com motor de áudio nativo
  (C++/Oboe via FFI). Público: adultos e idosos com perda auditiva em agudos.
target_scale:            "app mobile single-tenant (uma instalação = um paciente/clínica); sem SaaS multi-tenant"
primary_stack:            "Flutter 3.x / Dart >=3.4.0 <4.0.0"
runtime:                  "Flutter (Dart VM/AOT) + engine nativo C++ (Oboe/DSP) via FFI"
database:                 "Supabase Postgres — BaaS externo, consumido via SDK cliente (supabase_flutter); sem migrations locais geridas neste repo"
package_manager:          "pub (pubspec.yaml / pubspec.lock)"
deploy_target:            "Android (Play Store) via APK/AAB; iOS/macOS/Linux ainda não configurados neste repo (só android/, web/, windows/ existem)"
conceptual_architecture:  "Hoje: por camada/tipo (lib/screens, lib/ui/screens duplicado, lib/core, lib/services, lib/models, lib/audio_engine). Alvo documentado (não migrado): feature-first (lib/features/<domínio>/{data,domain,presentation}) — ver docs/ARCHITECTURE.md"
initial_domains:          "não gerados fisicamente neste bootstrap — módulo 03 ficou documentação-only (ver plano de viabilidade). Domínios de negócio identificados: audiometria, treino_auditivo (fonêmico/espacial/ruído), gamificação, relatórios_clínicos, autenticação"
multi_tenant:             false
auth_provider:            "Supabase Auth"
event_transport:          "N/A — sem backend próprio no repo; sem event bus/worker"
```

## Módulos

| # | Módulo | Estado | Verificado por |
|---|---|---|---|
| 00 | Manifest + plano-mestre | ✅ | Este arquivo criado com os 13 parâmetros preenchidos |
| 01 | Repo init (adaptado: sem package.json/tsconfig — pub + analysis_options.yaml) | ✅ | `.gitignore` cobre `.env`/`scratch/`; `.env.example` criado; `.editorconfig` criado; `.env` untracked (`git rm --cached`) |
| 02 | Context Engine (AGENTS.md, STATUS, DECISIONS) | ✅ | `AGENTS.md`, `CLAUDE.md`, `docs/STATUS.md`, `docs/DECISIONS.md`, `docs/adr/0001-bootstrap.md` criados |
| 03 | Topologia (DDD + hexagonal) — **doc-only por decisão explícita** | 🟡 | `docs/ARCHITECTURE.md` documenta a topologia-alvo; nenhuma pasta física movida (ver Regras invioláveis abaixo) |
| 04 | Validação de env (fail-fast) | ✅ | 2026-10-04: `lib/core/app_config.dart` (`--dart-define-from-file`) + `StartupErrorApp` no boot; recusa chave não pública. `test/app_config_test.dart` |
| 05 | Observabilidade + padrão de erros — **reduzido** (sem OTel/health/métricas de servidor) | 🟡 | 2026-10-04: `print` → `debugPrint`, desligado em release (dado clínico fora do logcat). Logger estruturado segue pendente |
| 06 | verify-rules core (tamanho, secrets) — **adaptado para Dart puro** | ✅ | `dart run tool/verify_rules.dart` |
| 07 | verify-rules arquitetura (boundaries, migrations, ciclos) | 🚫 | Migrations/RLS: N/A (`multi_tenant=false`, sem migrations locais). Boundaries/ciclos: adiado — não há topologia física (módulo 03) para verificar. check-status-doc absorvido no módulo 06 |
| 08 | generate core (migration, action, seed) | 🚫 | N/A — sem server actions/migrations locais neste app cliente |
| 09 | generate full (event, worker, domain, sync-skills) | 🚫 | event/worker: N/A. domain: N/A (nenhum domínio físico gerado). sync-skills: absorvido manualmente no módulo 14 |
| 10 | Git hooks versionados | ✅ | `core.hooksPath` → `.githooks/`; `.githooks/pre-commit` roda `dart run tool/verify_rules.dart` |
| 11 | CI/CD — o gate real (adaptado ao workflow Flutter existente) | ✅ | `.github/workflows/ci.yml` endurecido: sem `continue-on-error`, sem `--no-fatal-*`, com `dart run tool/verify_rules.dart` |
| 12 | Estratégia de testes + cobertura | 🟡 | Arnês documentado em `docs/ARCHITECTURE.md`/`CONTRIBUTING.md`; suíte real (hoje 1 arquivo) fica como débito registrado em `docs/STATUS.md`, não escrita neste bootstrap |
| 13 | Governança de deps e commits | ✅ | Hook `commit-msg` (Conventional Commits); `CHANGELOG.md`; `.github/dependabot.yml` (ecossistema `pub`) |
| 14 | Skills nativas de IA | ✅ | `.agent/skills/` mapeado no AGENTS.md como biblioteca canônica; `skills-library/CATALOG.md` documentado como catálogo genérico não curado (não é deste projeto) |
| 15 | Docs e onboarding | ✅ | `README.md` reescrito, `CONTRIBUTING.md` criado, `docs/RUNBOOK.md` criado, DoR/DoD no `AGENTS.md` |
| 16 | Auto-verificação final | ✅ | Ver última entrada de `docs/DECISIONS.md` e checklist ao final deste arquivo |

## Checklist de completude (módulo 16 — auto-verificação)

- [x] Context Engine (`AGENTS.md` + `CLAUDE.md` + `docs/DECISIONS.md`/`docs/adr/0001-bootstrap.md`) criado
- [x] `docs/STATUS.md` criado, apontado como 1ª leitura no `AGENTS.md`, refletindo auditoria brownfield real (arquivos confirmados por `Glob`, não presumidos)
- [x] Topologia por domínio documentada (`docs/ARCHITECTURE.md`) — **doc-only por decisão explícita**, nenhuma pasta física movida (confirmado: `lib/` fora do diff, ver `git status` abaixo)
- [🟡] Boundaries e enforcement automático — reduzido: só tamanho de arquivo e secrets (`tool/verify_rules.dart`); boundaries/ciclos adiados (sem topologia física para verificar, ver `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`)
- [🟡] Leis de segurança — adaptadas (seção 7 do `AGENTS.md`); `.env` untracked e gitignored; **rotação de chaves pendente** (ação humana)
- [🟡] Observabilidade — reduzida a nada ainda implementado (módulo 05 adiado, toca `lib/`)
- [x] `tool/verify_rules.dart` modular (`tool/checks/*.dart`), dentro do limite de linhas, testado com 4 cenários negativos reais (ver histórico de execução nesta sessão)
- [x] Hooks versionados (`core.hooksPath .githooks/`) — **NÃO em `.git/hooks/`**; testados via `git commit` real (mensagem inválida rejeitada, violação de tamanho abortou o commit, mensagem válida aceita)
- [x] CI rodando `dart run tool/verify_rules.dart` (paridade com o hook) + `flutter analyze` duro + secret-scan (gitleaks); branch protection **não confirmada** (sem acesso à API/painel do GitHub nesta sessão) — pendência humana
- [🟡] Estratégia de testes documentada; cobertura **não** enforced (suíte real é débito, não escrita)
- [x] Governança de deps + commits: hook `commit-msg` testado end-to-end via `git commit` real; `.github/dependabot.yml` (ecossistema `pub`); `CHANGELOG.md`
- [x] Skills nativas: `.agent/skills/` (fonte) copiado para `.claude/skills/` (descoberta pelo Claude Code); `skills-library/CATALOG.md` identificado como catálogo genérico não relacionado a este projeto
- [x] Docs de onboarding (`README.md`, `CONTRIBUTING.md`, `docs/RUNBOOK.md`) + DoR/DoD no `AGENTS.md` seção 10
- [x] Este `MASTER-PLAN.md` com os módulos aplicáveis ✅ e coluna "Verificado por" preenchida

**Encerramento:** ver última entrada de `docs/DECISIONS.md` ("Bootstrap Dev OS concluído").
`docs/STATUS.md` já lista "Fundação Dev OS (governança adaptada)" = ✅; features de produto
seguem como estavam (🟡 na maioria, auditoria brownfield sem alteração de comportamento).
`git status` confirmado limpo em `lib/`, `cpp/`, `android/`, `web/`, `windows/` — só arquivos de
governança/docs foram criados ou alterados (ver lista completa em `docs/DECISIONS.md`).

## Regras invioláveis deste bootstrap (adicionadas às do kit original)
- Nenhum arquivo em `lib/`, `cpp/`, `android/`, `web/`, `windows/` foi movido, renomeado ou reescrito.
- Nenhuma dependência de runtime (`pubspec.yaml` `dependencies:`) foi adicionada. Nenhum novo runtime de tooling (ex.: Node) foi introduzido — os scripts de governança são Dart puro.
- Segredos: `.env` foi removido do índice do git e adicionado ao `.gitignore`. **Rotação das chaves expostas (Supabase, Google TTS) e eventual limpeza do histórico do git NÃO foram feitas** — exigem ação humana fora do escopo deste bootstrap (ver `docs/DECISIONS.md`).
