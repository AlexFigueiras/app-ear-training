# Viabilidade e plano de adoção do kit `bootstrap/` (PROJECT OS v3) no `app-ear-training`

> Este documento é uma **análise + plano**. Ele não cria, move nem apaga nenhum arquivo de aplicação, não instala dependências e não altera `lib/`, `cpp/`, `android/`, `web/`, `windows/` ou `pubspec.yaml`. Cada item marcado como execução futura só deve ser feito em uma sessão dedicada, um módulo por vez, seguindo a própria metodologia do kit (ver `README.md` desta pasta).

---

## 1. Resposta direta

**É necessário?** Parcialmente sim. O projeto tem lacunas reais de governança: não existe `CLAUDE.md`/`AGENTS.md`, não há git hooks, o CI é frouxo (`continue-on-error` no format, `--no-fatal-infos/--no-fatal-warnings` no analyze), a cobertura de testes é ~0 (1 arquivo em `test/`), há duas fontes de verdade divergentes para o plano do produto (`#PROJECT_BRAIN.md` e `docs/MASTER_PLAN.md`), uma biblioteca de skills já existe mas está desconectada e com referências quebradas (`skills-library/CATALOG.md`), e — mais grave — **o `.env` com chaves reais (Supabase, Google TTS) está versionado no git**, fora do `.gitignore`.

**É viável aplicar o kit como está?** Não como está. O kit foi escrito para um produto **web/SaaS multi-tenant em Node + TypeScript + Postgres com server actions** (Next.js/Supabase-style). Este projeto é um **app Flutter mobile client-only**, com um engine de áudio nativo em C++/FFI, sem backend próprio no repositório (Supabase é consumido só como BaaS pelo cliente) e sem multi-tenancy. Nenhum dos 17 módulos menciona Flutter/Dart. Aplicar ao pé da letra introduziria Node como novo runtime de tooling, pastas de arquitetura (`domains/`, `worker/`, `infra/db/migrations`) que não correspondem a nada que exista aqui, e checks (RLS/tenant_id, health endpoints, event bus) que não têm o que verificar.

**Recomendação:** adotar uma **versão adaptada e podada** do kit — mesma filosofia (contexto ancorado, travas antes de geradores, verificação executável), mesma ordem de dependências, mas com script de verificação em **Dart puro** (não Node, para não introduzir novo runtime/stack) e com os módulos orientados a backend multi-tenant marcados como não aplicáveis ou reduzidos ao mínimo útil. A tabela da seção 3 cobre os 17 arquivos, um por um, sem exceção.

---

## 2. Por que não dá para simplesmente colar os módulos

| Descasamento | Onde aparece no kit | Realidade deste repo |
|---|---|---|
| Runtime de tooling assumido = Node (`npm run`, `scripts/*.js`) | 01, 06–09, 10, 11, 16 | Stack é Dart/Flutter; introduzir Node só para rodar scripts de governança seria **mudar a stack de tooling**, algo que você pediu para evitar |
| Arquitetura DDD/hexagonal com `domains/`, `infra/db/migrations`, `worker/` | 03, 07, 08, 09 | App tem estrutura Flutter idiomática (`lib/screens`, `lib/services`, `lib/core`, `lib/models`) — mover tudo para essa topologia é reescrita estrutural, não overlay |
| Migrations SQL locais com RLS/`tenant_id` obrigatórios | 07, 08 | Não há pasta de migrations no repo (há 3 `.sql` soltos na raiz); Supabase é gerenciado fora do repo; app é single-tenant (um paciente/clínica por instalação) |
| Observabilidade de servidor: OTel, métricas Prometheus, health/readiness endpoints | 05 | Não há servidor no repo para expor `/health` ou métricas — é um app cliente |
| Event bus / workers assíncronos | 09 | Não existe (nem faz sentido) processamento assíncrono de background jobs neste app |
| CI com `setup-node`/`setup-python` | 11 | CI já existe e usa `subosito/flutter-action`; a base do kit não cobre Flutter, mas o *padrão* (gate único, checks obrigatórios) é reaproveitável |

Esses descasamentos não invalidam o kit — apenas dizem que ele precisa ser **traduzido**, módulo a módulo, para o vocabulário Flutter/Dart antes de virar tarefa executável. É isso que a tabela abaixo faz.

---

## 3. Veredito por módulo (cobre os 17 arquivos, nenhum omitido)

Legenda: **APLICAR** = usar quase como está, só trocando exemplos de stack · **ADAPTAR** = manter o objetivo, reescrever o entregável para Dart/Flutter · **REDUZIR** = manter uma fração pequena e útil, descartar o resto por não ter equivalente · **ADIAR (só doc)** = documentar o alvo, sem mexer em código/estrutura agora · **N/A** = não se aplica a um app mobile client-only sem multi-tenant

| # | Arquivo | Veredito | O que muda para este projeto |
|---|---|---|---|
| 00 | `00-manifest.md` | **APLICAR** | `MASTER-PLAN.md` na raiz, com os 13 parâmetros preenchidos para a realidade do projeto: `primary_stack=Flutter/Dart`, `runtime=Flutter (Dart VM/AOT) + engine nativo C++ via FFI`, `database=Supabase Postgres (BaaS externo, sem migrations locais geridas aqui)`, `package_manager=pub`, `deploy_target=Android (Play Store) — iOS ainda não configurado`, `multi_tenant=false`, `auth_provider=Supabase Auth`, `event_transport=N/A (sem backend próprio no repo)` |
| 01 | `01-repo-init.md` | **ADAPTAR** | `.gitignore` já existe — só precisa **acrescentar `.env`** (hoje está commitado com segredos reais, ver §4); criar `.env.example`; os "7 scripts obrigatórios" viram alvos Dart: `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`, `flutter test --coverage`, `dart run tool/verify_rules.dart`, `dart run tool/generate.dart`. Nenhuma dependência Node é introduzida |
| 02 | `02-context-engine.md` | **APLICAR** (com reconciliação) | Criar `AGENTS.md` (fonte única) + ponteiro `CLAUDE.md`. Mas antes de criar `STATUS.md`/`DECISIONS.md` do zero, é preciso **reconciliar** `#PROJECT_BRAIN.md` e `docs/MASTER_PLAN.md`, que hoje são duas versões divergentes do mesmo PRD — decidir qual é canônica e apontar a outra para ela, senão o context engine nasce com uma terceira fonte de verdade |
| 03 | `03-topologia.md` | **ADIAR (só doc)** | Não mover fisicamente `lib/screens/` (existe uma duplicata: `lib/screens/` **e** `lib/ui/screens/` rodando em paralelo — sintoma de refatoração incompleta). Este plano só **documenta** uma topologia-alvo Flutter idiomática (`lib/features/<domínio>/{data,domain,presentation}`) em `docs/ARCHITECTURE.md`, sem executar a migração — isso é exatamente o tipo de mudança que você pediu para não fazer agora |
| 04 | `04-env-validation.md` | **ADAPTAR** (fase separada, com aprovação explícita) | Objetivo direto: um validador de env que falha cedo se faltar `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`GOOGLE_TTS_API_KEY`, em vez de o app quebrar silenciosamente depois. Isso **cria um arquivo novo e adiciona uma chamada no bootstrap do app** — é código de aplicação, então fica fora do "não alterar código" deste plano; entra como item follow-up explícito, não executado automaticamente |
| 05 | `05-observability.md` | **REDUZIR** | Descartar OTel/tracing distribuído, métricas Prometheus e health/readiness endpoints (não há servidor). Manter só a fatia que vale a pena: um logger estruturado simples para substituir os 32 `print`/`debugPrint` hoje espalhados em 12 arquivos, e uma classe de erro única em vez de exceptions ad-hoc. Mesma ressalva do 04: é código de app, não entra automaticamente |
| 06 | `06-verify-rules-core.md` | **ADAPTAR** | Reescrever `scripts/verify-rules.js` como `tool/verify_rules.dart` (Dart puro, sem pacote novo): check de tamanho de arquivo (300 aviso / 500 falha, com baseline para o legado) e check de segredos hard-coded em `.dart` (aqui não existe distinção client/server — em Flutter **todo** código é cliente, então o check vira "nenhuma chave/token literal no código-fonte", com o achado do `.env` commitado como caso de teste real) |
| 07 | `07-verify-rules-arch.md` | **REDUZIR** | Check de migrations/RLS: **N/A** enquanto `multi_tenant=false` (o próprio módulo já reporta `pass` nesse caso). Check de boundaries e de dependências circulares: útil, mas só ganha sentido depois que existir uma topologia-alvo (módulo 03) — por ora fica documentado, não implementado. Check de STATUS.md: mantém, é agnóstico |
| 08 | `08-generate-core.md` | **REDUZIR** | Gerador de migration/action é Postgres+server-action — **N/A** aqui. O único pedaço reaproveitável é a ideia de "não criar estrutura na mão": um gerador `tool/generate.dart feature <nome>` que cria o esqueleto de uma feature nova seguindo o padrão documentado no módulo 03 |
| 09 | `09-generate-full.md` | **REDUZIR** | Geradores de `event`/`worker` — **N/A** (sem event bus/worker neste app). `generate domain` vira o mesmo `generate feature` do item 08. `sync-skills` — **APLICAR**: é diretamente relevante, porque já existem duas bibliotecas de skills soltas (`.agent/skills/` com 13 pastas, e `skills-library/` quase vazia com catálogo quebrado) que precisam ser unificadas nesse mecanismo |
| 10 | `10-hooks.md` | **ADAPTAR** | Hook de pre-commit chamando `dart run tool/verify_rules.dart` em vez do runner Node. Pode usar `core.hooksPath .githooks` (zero dependência) em vez de lefthook, para não introduzir tooling Node |
| 11 | `11-ci.md` | **ADAPTAR** (evolução, não substituição) | O `.github/workflows/ci.yml` já existe e usa `subosito/flutter-action` — não recriar do zero. Endurecer: remover `continue-on-error` do `dart format`, remover `--no-fatal-infos --no-fatal-warnings` do `flutter analyze`, adicionar o passo `dart run tool/verify_rules.dart`, adicionar limiar de cobertura |
| 12 | `12-testes.md` | **ADAPTAR** | Trocar Vitest/Jest/pytest por `flutter test --coverage` + lcov; pirâmide de testes documentada. Escrever a suíte de testes em si (hoje há 1 arquivo para ~5.000 linhas de Dart) é um esforço grande à parte — este plano prepara o arnês e o limiar, não escreve os testes |
| 13 | `13-governanca.md` | **APLICAR** | Conventional commits via hook; `CHANGELOG.md`; Dependabot **com ecossistema `pub`** (suportado nativamente, diferente do que o módulo original menciona); auditoria de dependências via `dart pub outdated` (não existe um `cargo audit` equivalente exato para pub — registrar essa limitação) |
| 14 | `14-skills.md` | **APLICAR** | Prioridade alta: reconciliar `.agent/skills/` (13 skills já escritas, incluindo `AUDIOLOGIA_CLINICA` e `DSP_AUDIO_ENGINE`, específicas deste domínio) com o padrão `CONTEXT.md → SKILL.md` do kit, e consertar as referências quebradas de `skills-library/CATALOG.md` |
| 15 | `15-docs-onboarding.md` | **APLICAR** | `README.md` hoje é o boilerplate padrão do `flutter create` — reescrever com setup real. `CONTRIBUTING.md` novo. `docs/ARCHITECTURE.md` recebe a topologia-alvo adiada do módulo 03. Consolidar `#PROJECT_BRAIN.md`/`docs/MASTER_PLAN.md` conforme decidido no módulo 02 |
| 16 | `16-auto-verificacao.md` | **APLICAR** | Gate final adaptado: comandos trocados para `flutter`/`dart`, mesma lógica de evidência real exibida, não descrita |

Resumo numérico: **6 aplicáveis quase diretos** (00, 02, 13, 14, 15, 16), **6 adaptados para Dart/Flutter** (01, 04, 05, 06, 10, 11), **4 reduzidos por falta de equivalente** (07, 08, 09, 12 parcialmente), **1 adiado só para documentação** (03). Nenhum module fica de fora da análise.

---

## 4. Achado urgente, independente deste plano

O `.env` versionado no git (`git ls-files` confirma que está *tracked*) contém `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `GOOGLE_TTS_API_KEY` reais, e não está no `.gitignore`. Isso é uma exposição de segredo ativa, não uma questão de governança futura. O módulo 01 só garante que *daqui para frente* `.env` fique ignorado — ele **não** rotaciona chaves nem limpa o histórico do git. Recomendo, independentemente de seguir ou não o resto deste plano:
1. Rotacionar a `GOOGLE_TTS_API_KEY` e a chave/projeto Supabase expostos.
2. Adicionar `.env` ao `.gitignore` e remover do índice (`git rm --cached .env`) — parte natural do módulo 01.
3. Avaliar se vale reescrever o histórico do git para remover o segredo dos commits antigos (decisão sua, é uma operação destrutiva que não farei sem pedido explícito).

Isso fica fora do escopo "não alterar código/estrutura" porque é uma correção de segurança, não uma refatoração — mas só deve ser executado quando você autorizar explicitamente.

---

## 5. Ordem de execução recomendada (podada)

Mantendo o grafo de dependências do `README.md` original, mas removendo o que virou N/A:

```
00 manifest ──▶ 02 context-engine (com reconciliação de docs) ──▶ 03 topologia (só doc)
                                                                        │
                                            ┌───────────────────────────┤
                                            ▼                           ▼
                             01 repo-init (.env fix incluso)     14 skills (reconciliação)
                                            │
                                            ▼
                              06 verify-rules (Dart) ──▶ 10 hooks ──▶ 11 ci (evolução)
                                            │
                                            ▼
                                   13 governança ──▶ 15 docs-onboarding ──▶ 16 auto-verificação

                    [fora da sequência automática — requerem aprovação por tocarem lib/]
                    04 env-validation  ·  05 observability (reduzido)  ·  12 testes (suíte real)
```

07, 08 e 09 não entram na sequência de execução como módulos próprios — o pouco que sobrou de cada um (boundaries/deps circulares, gerador de feature, sync-skills) já foi absorvido nos módulos 03, 09→14 e 06 acima.

Cada módulo continua sendo **uma sessão, um critério de aceite executável, sem avançar sem prova** — exatamente a regra do `README.md` original. Este documento não substitui essa disciplina, só faz a tradução prévia para que cada sessão futura já saiba o que construir em vez de tentar aplicar literalmente um exemplo Next.js/Postgres a um app Flutter.

---

## 6. O que este plano explicitamente não faz

- Não move, renomeia ou reescreve nada em `lib/`, `cpp/`, `android/`, `web/`, `windows/`.
- Não adiciona Node, npm, nem qualquer runtime novo como dependência de tooling.
- Não resolve a duplicata `lib/screens/` vs `lib/ui/screens/` (fica documentada como débito, não corrigida).
- Não rotaciona segredos nem reescreve histórico do git (ação humana, ver §4).
- Não escreve a suíte de testes que falta nem o `env.dart`/logger reais — esses ficam como itens follow-up que pedem aprovação explícita antes de tocar código do app.
