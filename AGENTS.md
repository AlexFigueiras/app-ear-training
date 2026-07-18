# AGENTS.md — fonte única da verdade (ear_training / BOSYN)

> Qualquer IA (Claude, Gemini, Cursor, Windsurf, etc.) que trabalhe neste repositório obedece a
> este arquivo. Ponteiros (`CLAUDE.md`, `GEMINI.md`) apontam para cá e não contêm regra própria.
>
> **Adaptação declarada:** este AGENTS.md é uma tradução do kit `bootstrap/*.md` (PROJECT OS v3,
> escrito para SaaS multi-tenant Node/TS/Postgres) para a realidade real deste projeto: **app
> Flutter mobile client-only**, com engine de áudio nativo em C++/FFI, sem backend próprio no
> repo (Supabase é BaaS externo) e sem multi-tenancy. A tradução módulo a módulo está em
> `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`; o estado de cada módulo está em `MASTER-PLAN.md`.

## 1. Visão do projeto + princípios operacionais

**O que é:** app Flutter de reabilitação auditiva baseada em plasticidade neural (marca de
produto: BOSYN). Aplica audiogramas clínicos a testes de limiar tonal, discriminação fonêmica,
atenção espacial e fala no ruído, com engine de áudio nativo (C++/Oboe via FFI) para DSP em
baixa latência. Contexto clínico — ver `#PROJECT_BRAIN.md` (visão de produto/roadmap) e
`docs/MASTER_PLAN.md` (SSOT de design/gamificação clínica).

**Princípios operacionais (transcritos do kit original, válidos aqui):**
- **Boundaries explícitos > convenção implícita.** Regra que importa deve ser verificável por
  máquina (`dart tool/verify_rules.dart`), não confiada à memória de quem editou.
- **Automação é a única regra que sobrevive.** Regra que depende de disciplina humana decai.
  Toda lei tem um *enforcer* (verify-rules + CI).
- **Contexto local junto do código.** Skills em `.agent/skills/` carregam o contexto de domínios
  críticos (ex.: `AUDIOLOGIA_CLINICA`, `DSP_AUDIO_ENGINE`). Leia o contexto do que for tocar.
- **Determinismo por scaffolding.** *(Adaptado — ver nota abaixo.)* Neste bootstrap não existe
  gerador `generate` (módulos 08/09 do kit original ficaram fora de escopo, ver
  `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`). Estruturas repetitivas continuam criadas à mão até
  que um gerador equivalente seja construído.
- **Stack-neutral no núcleo, específico na borda.** As leis são universais; o *como* se adapta
  via Stack Adapter (seção 9).
- **Fail-fast e observável.** O sistema deve falhar cedo e alto. *(Hoje parcialmente cumprido —
  ver módulos 04/05 em `MASTER-PLAN.md`, adiados por exigirem tocar código de app.)*
- **Estado visível > estado implícito.** O que existe e funciona é registrado em
  `docs/STATUS.md`, não deixado na cabeça de alguém.

## 2. Protocolo Multiagente (íntegro, com adaptações explícitas)

1. **Registro de Decisões obrigatório:** toda tarefa que implemente tela, altere regra clínica,
   mude contrato de dados, resolva bug não-trivial ou tome decisão arquitetural adiciona entrada
   datada no **topo** de `docs/DECISIONS.md`. Sem entrada = tarefa incompleta.
2. **Geração obrigatória por CLI — N/A por ora.** O kit original proíbe criar manualmente
   migrations/actions/domains e exige um gerador (`generate`). Este bootstrap não construiu esse
   gerador (ver módulos 08/09 em `MASTER-PLAN.md`) porque não há migrations locais nem topologia
   física por domínio neste app. Enquanto isso não mudar, features continuam criadas à mão,
   seguindo a topologia-alvo documentada em `docs/ARCHITECTURE.md`.
3. **Poluição Zero:** temporários deletados antes da conclusão; rascunhos persistentes só em
   `/scratch/` (gitignored — ver `.gitignore`).
4. **Guardrails de Dependência:** nunca adicionar dependência de runtime (`pubspec.yaml`
   `dependencies:`) sem consentimento explícito e prévio do humano. Exceção única: tooling de
   fundação (registrado em `docs/DECISIONS.md`) — e mesmo assim, preferir Dart puro (ver módulo
   01: este bootstrap deliberadamente NÃO introduziu Node ou qualquer runtime novo de tooling).
5. **Mudança de schema é evento de primeira classe:** o schema do Supabase é gerido fora deste
   repo (não há `infra/db/migrations/` aqui). Os 3 `.sql` soltos na raiz
   (`supabase_migration_001.sql`, `supabase_migration_002.sql`, `supabase_setup.sql`) são
   histórico de setup manual — trate qualquer alteração de schema com o mesmo cuidado de uma
   migration versionada e registre em `docs/DECISIONS.md`.
6. **Pare-e-pergunte:** interrompa e consulte o humano para violar uma Lei de Segurança (seção
   7), adicionar nova dependência de runtime, quebrar um contrato público entre módulos, mexer em
   `lib/`, `cpp/`, `android/`, `web/`, `windows/` fora do escopo pedido, ou tomar decisão
   arquitetural irreversível (ex.: mover fisicamente a estrutura de pastas do app).
7. **Estado é de primeira classe — ler ANTES, atualizar DEPOIS:** antes de qualquer feature, leia
   `docs/STATUS.md`; se está ✅, abra os arquivos apontados e parta do que existe — NUNCA
   reconstrua. Ao concluir, atualize a linha do STATUS na MESMA tarefa, junto com a entrada em
   `docs/DECISIONS.md`.

## 3. Primeira leitura obrigatória

**Leia `docs/STATUS.md` antes de propor ou implementar qualquer coisa.** Não reconstrua o que já
está ✅. O histórico do *porquê* das decisões fica em `docs/DECISIONS.md`.

## 4. Mapa de Contexto

| Domínio / módulo crítico | Responsabilidade | Contexto local |
|---|---|---|
| Audiologia clínica | Regras de audiograma, limiares, mascaramento, SNR | `.agent/skills/AUDIOLOGIA_CLINICA/SKILL.md` |
| Engine de áudio (DSP nativo) | FFI, filtros FIR/biquad, latência, ciclo de vida do engine C++ | `.agent/skills/DSP_AUDIO_ENGINE/SKILL.md`, `SETUP_AND_MIGRATION.md` |
| Demais skills operacionais | Padrões de API, backend, banco, debugging sistemático, git, etc. | `.agent/skills/*/SKILL.md` (ver seção 8 do mapa completo em `docs/STATUS.md`) |

Este mapa lista hoje as skills já existentes (ver módulo 14 em `MASTER-PLAN.md`). Não há
`domains/<x>/CONTEXT.md` porque a topologia por domínio ficou documentação-only (seção 5).

**Descoberta pelo Claude Code:** as 13 skills foram copiadas de `.agent/skills/` para
`.claude/skills/` (formato de frontmatter já compatível) para que o Claude Code as descubra numa
sessão nova — antes deste bootstrap nenhuma aparecia disponível. `.agent/skills/` continua sendo
a fonte de verdade; `.claude/skills/` é uma cópia sincronizada manualmente (sem gerador
automático, ver `.claude/skills/README.md` e módulo 14 em `MASTER-PLAN.md`).

## 5. Topologia do repositório

**Estado atual (não alterado por este bootstrap):** organização por camada/tipo, com uma
duplicidade conhecida entre `lib/screens/` e `lib/ui/screens/` (débito registrado em
`docs/STATUS.md`, não corrigido aqui).

**Topologia-alvo (documentada, não migrada):** ver `docs/ARCHITECTURE.md` para a árvore completa
feature-first (`lib/features/<domínio>/{data,domain,presentation}`), a regra de dependência
(presentation → domain puro ← data) e as regras de boundary entre features. Migrar fisicamente
para essa topologia é uma decisão arquitetural irreversível (regra 6 do Protocolo) — exige
aprovação humana explícita e não faz parte deste bootstrap.

## 6. Padrões de Qualidade

- `> 300` linhas líquidas de código (sem comentários/linhas vazias) por arquivo `.dart` = warning;
  `> 500` = proibido (falha `tool/verify_rules.dart`). Arquivos legados acima do limite entram no
  baseline (`tool/file_size_baseline.json`) como catraca — não podem crescer, só encolher.
- Widgets/telas acima de ~150 linhas ou mais de uma responsabilidade → extrair subwidgets.
- Sem arquivos "Deus": models, contratos e helpers em arquivos dedicados.
- Responsabilidade Única: propósito declarável em uma frase; se precisa de "e", divida.
- Tipagem estrita: evitar `dynamic` sem justificativa explícita em comentário.

## 7. Leis de Segurança invioláveis

*(Adaptadas de multi-tenant/RLS-por-tenant para single-tenant com isolamento por usuário —
`multi_tenant: false`, ver `MASTER-PLAN.md`. O próprio produto já assume isolamento por
`user_id`, ver `#PROJECT_BRAIN.md` §3 e `docs/MASTER_PLAN.md` §4.2.)*

1. **Isolamento por usuário:** toda tabela do Supabase que guarda dado de paciente/sessão tem RLS
   habilitada com policy baseada em `auth.uid() = user_id` (ou equivalente) — não em `tenant_id`,
   já que o app é single-tenant por instalação, mas multi-usuário no backend compartilhado.
2. **Credenciais privilegiadas jamais neste repositório.** Este app é 100% código cliente — a
   `SUPABASE_ANON_KEY` (pública, restrita por RLS) é a única aceitável aqui. Nenhuma
   `service_role key` ou admin key do Supabase, nem chave de API server-side irrestrita, pode
   aparecer em `lib/`, `.env`, ou qualquer commit.
3. **`.env` jamais versionado; `.env.example` sempre versionado.** Ver módulo 01 em
   `MASTER-PLAN.md`. **Nota de incidente:** até este bootstrap, `.env` estava commitado com
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `GOOGLE_TTS_API_KEY` reais. Foi removido do índice do
   git e adicionado ao `.gitignore` — **rotação das chaves e eventual limpeza do histórico do git
   NÃO foram feitas** (exigem ação humana fora deste bootstrap, ver `docs/DECISIONS.md`).
4. **Validação de env em boot: pendente.** O kit original exige que o app falhe cedo se faltar
   env var obrigatória (módulo 04). Isso exigiria tocar `lib/main.dart` — fica registrado como
   item follow-up em `docs/STATUS.md`, não executado neste bootstrap.
5. **Secret scanning:** `tool/verify_rules.dart` (módulo 06) varre o código-fonte à procura de
   segredos hard-coded fora de `.env*`. Não há secret-scan de histórico de git configurado.

## 8. Como rodar e verificar

```bash
flutter pub get                                            # instalar dependências
flutter run                                                # rodar em dev
flutter analyze                                             # lint/análise estática
dart format --output=none --set-exit-if-changed lib test tool   # checar formatação
flutter test                                                 # rodar testes
flutter test --coverage                                      # rodar testes com cobertura
dart tool/verify_rules.dart                               # verify-rules (módulo 06)
```

Não há comando `generate` (ver seção 2, item 2). Não há comando `dev server` de backend — o
único "backend" é o Supabase gerenciado externamente.

## 9. Stack Adapter

| Conceito universal (kit original) | Materialização neste projeto |
|---|---|
| `package.json` scripts | Comandos `flutter`/`dart` documentados na seção 8 (sem manifesto de scripts — pub não tem esse mecanismo) |
| `tsconfig.json strict` | `analysis_options.yaml` (`flutter_lints`) — ver oportunidade de endurecer registrada em `docs/STATUS.md` |
| `scripts/verify-rules.js` (Node) | `tool/verify_rules.dart` (Dart puro, sem dependência nova) |
| `scripts/generate.js` | Não construído neste bootstrap (N/A, ver seção 2) |
| `domains/<x>/` (DDD físico) | `lib/features/<x>/` — **documentado em `docs/ARCHITECTURE.md`, não migrado** |
| Migrations SQL + RLS por `tenant_id` | Schema gerido fora do repo no Supabase; RLS por `user_id` (seção 7) |
| Server actions | N/A — chamadas diretas ao SDK `supabase_flutter` em `lib/services/` |
| Event bus / workers | N/A — sem processamento assíncrono de background neste app |
| Observabilidade OTel/Prometheus/health endpoints | N/A (sem servidor); reduzido a logger estruturado local — **pendente**, ver módulo 05 em `MASTER-PLAN.md` |
| `lefthook.yml` | `core.hooksPath .githooks/` (zero dependência nova) |
| `npm audit` / `pip-audit` | `dart pub outdated` no CI (não há equivalente exato de `cargo audit` para `pub`; registrado como limitação) |
| Dependabot ecossistema `npm`/`pip` | Dependabot ecossistema `pub` (suportado nativamente) |

## 10. DoR / DoD

**Definition of Ready (antes de começar qualquer feature):**
- `docs/STATUS.md` lido — estado da feature confirmado, não vou reconstruir o que está ✅.
- Skill relevante em `.agent/skills/` lida, se existir para o domínio (ex.: `AUDIOLOGIA_CLINICA`,
  `DSP_AUDIO_ENGINE`).
- Se a tarefa tocar `cpp/` (engine nativo), `SETUP_AND_MIGRATION.md` lido antes.

**Definition of Done (antes de concluir):**
- `dart tool/verify_rules.dart` passa.
- `flutter analyze` e `dart format --set-exit-if-changed` passam.
- `flutter test` passa (cobertura ainda não é enforced — ver módulo 12 em `MASTER-PLAN.md`).
- `docs/STATUS.md` atualizado (linha da feature: estado + arquivos).
- Entrada em `docs/DECISIONS.md`.
- `/scratch` limpo, nenhum segredo exposto, arquivos dentro do limite de linhas (seção 6),
  nenhuma dependência de runtime nova sem aprovação humana registrada.
