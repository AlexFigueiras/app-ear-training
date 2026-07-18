# ADR 0001 — Adoção de um Dev OS adaptado (kit `bootstrap/*.md`)

## Status
Accepted — 2026-07-18

## Contexto
O repositório `ear_training` (app Flutter de reabilitação auditiva, engine de áudio nativo em
C++/FFI, Supabase como BaaS) cresceu sem uma camada de governança: sem `AGENTS.md`/`CLAUDE.md`
para ancorar agentes de IA, sem git hooks, CI frouxo (`continue-on-error` no format,
`--no-fatal-infos/--no-fatal-warnings` no analyze), cobertura de testes essencialmente nula, duas
fontes de verdade divergentes para o PRD do produto (`#PROJECT_BRAIN.md` e
`docs/MASTER_PLAN.md`), uma biblioteca de skills (`.agent/skills/`) desconectada de qualquer
mecanismo de descoberta, e um `.env` com segredos reais versionado no git.

Um kit de bootstrap (`bootstrap/00-manifest.md` a `bootstrap/16-auto-verificacao.md`, 17 módulos)
estava disponível no repositório, mas foi escrito para um produto web/SaaS multi-tenant em
Node+TypeScript+Postgres com server actions — nenhum módulo menciona Flutter, Dart ou mobile.

## Decisão
Adotar o kit de forma **adaptada e podada**, preservando sua filosofia (contexto ancorado, travas
antes de geradores, verificação executável, um módulo por vez) mas traduzindo cada entregável
para Dart/Flutter, e descartando ou adiando o que não tem equivalente em um app mobile
client-only sem multi-tenancy e sem backend próprio no repositório. O veredito módulo a módulo
está em `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`; o registro de execução, em `MASTER-PLAN.md` e
`docs/DECISIONS.md`.

Decisão explícita de escopo: nenhuma alteração em `lib/`, `cpp/`, `android/`, `web/`, `windows/`;
nenhuma dependência de runtime nova; nenhum runtime de tooling novo (os scripts de governança são
Dart puro, não Node).

## Consequências
- Ganho: contexto centralizado e verificável para agentes de IA, hooks e CI que efetivamente
  bloqueiam violações, governança de commits/deps, skills mapeadas, docs de onboarding reais.
- Custo aceito: vários módulos do kit original (07, 08, 09) ficaram largamente `🚫` — não há
  migrations locais, event bus, workers ou geradores de domínio, porque não fazem sentido aqui.
- Débito registrado, não resolvido: validação de env em boot, logger estruturado, suíte de testes
  real e a duplicidade `lib/screens/`/`lib/ui/screens/` seguem pendentes em `docs/STATUS.md` —
  todos exigem tocar código de app e por isso ficaram fora do escopo desta rodada.
- Risco tratado parcialmente: `.env` foi untracked do git; rotação das chaves expostas
  (Supabase, Google TTS) e limpeza de histórico continuam pendentes de ação humana.
