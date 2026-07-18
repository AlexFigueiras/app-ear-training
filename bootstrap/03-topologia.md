# Módulo 03 — Topologia por domínio (DDD + Hexagonal)

## Depende de: 02

## Objetivo
Criar o esqueleto físico do repositório organizado por **domínio de negócio** (não por tecnologia), com a regra de dependência hexagonal documentada no AGENTS.md.

## Entregáveis obrigatórios

### 1. Estrutura de pastas
Crie (com `.gitkeep` onde vazio). Adapte extensões à stack:

```
<project-root>/
├── domains/                       # ❤️ LÓGICA DE NEGÓCIO (vazia por ora; domínios nascem pelo generate no módulo 09)
├── events/                        # 📣 CONTRATOS de eventos compartilhados
│   └── (registry nasce no módulo 09)
├── shared/                        # 🔧 INFRA TRANSVERSAL (SEM regra de negócio)
│   ├── observability/             # (módulo 05)
│   ├── config/                    # (módulo 04)
│   ├── security/
│   ├── errors/                    # (módulo 05)
│   └── utils/
├── infra/                         # adaptadores técnicos globais
│   ├── db/migrations/             # SQL gerado por CLI (módulo 08)
│   ├── queue/
│   └── cache/
├── app/                           # 🖥️ ENTREGA (frontend/API) — só wiring, SEM regra
├── worker/                        # ⚙️ background — só wiring, SEM regra
├── scripts/
│   └── lib/                       # módulos dos scripts (06–09)
└── docs/                          # já existe (módulo 02)
```

### 2. Anatomia de um domínio (documentar no AGENTS.md, seção 5)
Cada `domains/<domain>/` terá, quando criado pelo gerador:
```
<domain>/
├── CONTEXT.md             # playbook local do domínio
├── index.ts               # API PÚBLICA — única porta de entrada do domínio
├── types.ts
├── schema.ts              # validação (Zod / Pydantic / ...)
├── domain/                # entidades + regras PURAS (zero I/O)
├── services/              # casos de uso / orquestração
├── ports/                 # interfaces (contratos de saída)
├── adapters/              # implementações de infra DESTE domínio
├── actions/               # entrypoints (server actions / handlers / controllers)
├── events/                # eventos publicados/consumidos pelo domínio
├── components/            # UI do domínio (se houver)
└── __tests__/
```

### 3. A Regra de Dependência (documentar no AGENTS.md, com o diagrama)
Dentro de cada domínio, dependências apontam **para dentro**:
```
actions / components  →  services  →  domain (puro)
                              │
                              ▼
                            ports (interfaces)  ◀── adapters (infra) implementam
```
- `domain/` é **puro**: sem banco, rede ou framework. Testável em memória.
- `services/` orquestra e fala com o mundo **apenas via `ports/`**.
- `adapters/` implementam as ports com infra concreta (DB, fila, API externa) — trocável sem tocar na regra de negócio.

### 4. Regras de boundary (documentar no AGENTS.md)
- **Tecnologia ≠ negócio:** `app/`, `worker/`, `infra/` não contêm lógica de negócio — só wiring (DI, roteamento, configuração). Toda regra mora em `domains/`.
- **Domínios não se acoplam diretamente:** proibido `domains/crm → domains/billing` etc. Comunicação apenas por **eventos**, **contratos** ou **serviços compartilhados aprovados** em `shared/`. Import de outro domínio, quando inevitável, só pelo `index.ts` público — nunca internals. Preferir eventos.
- **Eventos como espinha dorsal:** todo evento relevante tem contrato próprio (schema + tipo versionado) registrado em `events/registry.ts`. Nenhum domínio executa lógica interna de outro diretamente. Estratégia de evolução: bus in-process síncrono na fase 1; o contrato versionado permite migrar para SQS/Kafka/NATS na fase 2 sem reescrever domínios.

O enforcement automático dessas regras chega no módulo 07 — aqui elas entram como lei escrita.

### 5. Completar a seção 5 do AGENTS.md
Substituir o placeholder deixado no módulo 02 pela topologia real (árvore do item 1 + anatomia + regra de dependência + boundaries).

## Regras invioláveis deste módulo
- Nenhum arquivo de código de produto — só estrutura, `.gitkeep` e documentação.
- Não criar nenhum domínio manualmente (nasce pelo generate, módulo 09).

## Critério de aceite
- [ ] Árvore criada confere com o item 1 (verificar com `tree` ou `find`).
- [ ] AGENTS.md seção 5 preenchida com topologia, diagrama hexagonal e regras de boundary.
- [ ] `domains/` está vazia (nenhum domínio improvisado).

## Ao concluir
1. Marcar ✅ na linha 03 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` se algo foi adaptado à stack (ex.: sem `worker/` em stack serverless).
3. PARAR. Não iniciar o módulo 04 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
