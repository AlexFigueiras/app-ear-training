# Kit de Bootstrap — PROJECT OS v3 decomposto

Decomposição do `PROJECT-OS-v3.md` em **17 módulos autocontidos** (`00` a `16`), numerados na ordem ideal de implementação, para uso em projetos novos com agentes de IA em IDE.

## Por que decomposto

Colar o documento inteiro faz o agente criar um plano simplificado e deixar itens para trás. Aqui, cada módulo é uma tarefa fechada com **entregáveis exaustivos** e **critério de aceite executável** (incluindo testes negativos). O agente não avança sem provar que o módulo atual está completo.

## Como usar

1. Cole o **módulo 00** no agente do projeto novo. Ele pedirá os parâmetros, criará o `MASTER-PLAN.md` e parará.
2. A cada nova interação, cole **um único módulo** (o próximo ⬜ do MASTER-PLAN) e diga apenas: *"execute este módulo"*.
3. Ao final de cada módulo, confira a seção **Critério de aceite** — se algum comando não passou, o módulo não terminou.
4. Nunca deixe o agente executar dois módulos na mesma resposta, mesmo que ele se ofereça.

## Ordem e dependências

```
00 manifest ──▶ 01 repo-init ──▶ 02 context-engine ──▶ 03 topologia
                                                          │
                        ┌─────────────────────────────────┤
                        ▼                                 ▼
                04 env-validation                 05 observability
                        └────────────┬────────────────────┘
                                     ▼
                 06 verify-rules-core ──▶ 07 verify-rules-arch
                                     ▼
                   08 generate-core ──▶ 09 generate-full
                                     ▼
                     10 hooks ──▶ 11 ci ──▶ 12 testes ──▶ 13 governanca
                                     ▼
                  14 skills ──▶ 15 docs-onboarding ──▶ 16 auto-verificacao
```

As travas (06–07) vêm **antes** dos geradores (08–09) de propósito: todo código gerado já nasce validado.
