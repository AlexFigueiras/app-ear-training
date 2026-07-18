# Módulo 00 — Manifest: parâmetros de entrada + plano-mestre

## Depende de: nada (é o primeiro)

## Objetivo
Registrar os parâmetros do projeto e criar o `MASTER-PLAN.md` que rastreia o progresso do bootstrap entre sessões.

## Contexto para você, agente

Você vai instalar um **sistema operacional de desenvolvimento (Dev OS)** em 17 módulos sequenciais. A meta primária **não é gerar código de produto** — é instalar a infraestrutura, automações e travas (*guardrails*) que mantêm o projeto saudável conforme cresce. Nenhuma regra de negócio, tela, endpoint, schema ou integração pode ser escrita antes de a fundação estar criada e validada.

**Regra de precedência** (em caso de conflito, do mais forte ao mais fraco):
1. **Leis de Segurança** (módulos 04, 06, 07, 08) — invioláveis, sem exceção.
2. **Regras de Boundary e Arquitetura** (módulos 03, 07).
3. **Padrões de Qualidade** (módulo 06).
4. Preferências de estilo suas.

Quando uma instrução do usuário colidir com 1–3, você **para e avisa** em vez de obedecer silenciosamente.

**Regra de execução:** um módulo por resposta. Ao concluir este módulo, PARE e aguarde o próximo ser colado.

## Entregáveis obrigatórios

### 1. Parâmetros preenchidos
Peça ao humano que preencha (ou confirme) TODOS os campos. Se algum estiver vazio ou ambíguo, **pergunte antes de criar qualquer arquivo — nunca invente**:

```yaml
project_name:            # ex: "Atlas CRM"
description:             # 3–5 linhas: o que o sistema faz e para quem
target_scale:            # ex: "multi-tenant SaaS B2B, ~100 tenants no ano 1"
primary_stack:           # ex: "Next.js 15 (App Router) + TypeScript"
runtime:                 # ex: "Node 22" | "Python 3.12" | "Go 1.23"
database:                # ex: "PostgreSQL 16 (Supabase)" | "MySQL" | "MongoDB"
package_manager:         # ex: "pnpm" | "npm" | "uv" | "cargo"
deploy_target:           # ex: "Vercel" | "AWS ECS" | "Fly.io" | "on-prem"
conceptual_architecture: # ex: "Monólito modular com domains/ + worker/ + infra/db"
initial_domains:         # ex: [auth, billing, crm, inventory, scheduling]
multi_tenant:            # true | false
auth_provider:           # ex: "Supabase Auth" | "Clerk" | "custom JWT" | "none"
event_transport:         # ex: "in-process bus (fase 1) → SQS/Kafka (fase 2)"
```

### 2. `MASTER-PLAN.md` na raiz do projeto
Crie exatamente com este conteúdo (parâmetros preenchidos no topo):

```md
# MASTER-PLAN — progresso do bootstrap Dev OS
> Rastreia o estado do PRÓPRIO bootstrap. Um agente que retoma o trabalho lê isto primeiro.
> Legenda: ✅ concluído e verificado · 🟡 em andamento · ⬜ a fazer
> Regra: nenhum módulo inicia antes de o anterior estar ✅ (verificação de aceite executada).

## Parâmetros do projeto
(colar aqui o YAML preenchido)

## Módulos
| # | Módulo | Estado | Verificado por |
|---|---|---|---|
| 00 | Manifest + plano-mestre | 🟡 | — |
| 01 | Repo init | ⬜ | — |
| 02 | Context Engine (AGENTS.md, STATUS, DECISIONS) | ⬜ | — |
| 03 | Topologia (DDD + hexagonal) | ⬜ | — |
| 04 | Validação de env (fail-fast) | ⬜ | — |
| 05 | Observabilidade + padrão de erros | ⬜ | — |
| 06 | verify-rules core (tamanho, secrets) | ⬜ | — |
| 07 | verify-rules arquitetura (boundaries, migrations, ciclos) | ⬜ | — |
| 08 | generate core (migration, action, seed) | ⬜ | — |
| 09 | generate full (event, worker, domain, sync-skills) | ⬜ | — |
| 10 | Git hooks versionados | ⬜ | — |
| 11 | CI/CD — o gate real | ⬜ | — |
| 12 | Estratégia de testes + cobertura | ⬜ | — |
| 13 | Governança de deps e commits | ⬜ | — |
| 14 | Skills nativas de IA | ⬜ | — |
| 15 | Docs e onboarding | ⬜ | — |
| 16 | Auto-verificação final | ⬜ | — |
```

Na coluna "Verificado por", registre o comando executado e o resultado (ex.: `node scripts/verify-rules.js → exit 0`).

## Regras invioláveis deste módulo
- Não criar nenhum outro arquivo além do `MASTER-PLAN.md`.
- Não instalar nenhuma dependência.
- Não propor "adiantar" módulos futuros.

## Critério de aceite
- [ ] Todos os 13 parâmetros preenchidos sem ambiguidade (perguntou ao humano onde necessário).
- [ ] `MASTER-PLAN.md` existe na raiz com a tabela dos 17 módulos.
- [ ] Linha do módulo 00 marcada ✅.

## Ao concluir
1. Marcar ✅ na linha 00 do `MASTER-PLAN.md`.
2. PARAR. Não iniciar o módulo 01 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
