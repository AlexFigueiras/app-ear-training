# Módulo 02 — Context Engine de 3 camadas

## Depende de: 01

## Objetivo
Criar a ancoragem de contexto que toda IA consome: `AGENTS.md` (fonte única da verdade), ponteiros por ferramenta, `docs/STATUS.md` (estado) e `docs/DECISIONS.md` (histórico).

## Entregáveis obrigatórios

### 1. `AGENTS.md` — fonte única da verdade
Arquivo canônico na raiz. Toda IA obedece. Deve conter, **nesta ordem**:
1. Visão do projeto + princípios operacionais (lista abaixo, item 1a).
2. Protocolo Multiagente **integral** (item 1b — transcreva as 7 regras, não resuma).
3. **Ponteiro de PRIMEIRA leitura** para `docs/STATUS.md` e `docs/DECISIONS.md`. Texto explícito: *"leia o STATUS antes de propor/implementar; não reconstrua o que está ✅"*.
4. **Mapa de Contexto** (tabela: domínio → responsabilidade → caminho do `CONTEXT.md`). Nesta fase fica vazia com o cabeçalho pronto; o módulo 09 a preenche.
5. Topologia do repositório (será colada no módulo 03; deixe a seção com placeholder claro).
6. Padrões de Qualidade (item 1c).
7. Leis de Segurança invioláveis (item 1d).
8. **Como rodar e verificar**: comandos de dev, lint, typecheck, test, `verify`, `generate`.
9. Stack Adapter preenchido (tabela: conceito universal → materialização na stack, derivada dos parâmetros do MASTER-PLAN).

**1a. Princípios operacionais (transcrever):**
- **Boundaries explícitos > convenção implícita.** Tudo que for regra deve ser verificável por máquina, não confiado à memória de quem editou.
- **Automação é a única regra que sobrevive.** Regra que depende de disciplina humana decai. Toda lei tem um *enforcer* (`verify-rules` + CI).
- **Contexto local junto do código.** Cada módulo crítico carrega seu próprio `CONTEXT.md`. A IA lê o contexto do que vai tocar antes de tocar.
- **Determinismo por scaffolding.** Estruturas repetitivas nascem de geradores, não de improviso.
- **Stack-neutral no núcleo, específico na borda.** As leis são universais; o *como* se adapta via Stack Adapter.
- **Fail-fast e observável.** O sistema falha cedo, alto e com rastro auditável.
- **Estado visível > estado implícito.** O que existe e funciona é registrado em `docs/STATUS.md`, não deixado na cabeça de alguém.

**1b. Protocolo Multiagente (transcrever integral):**
1. **Registro de Decisões obrigatório:** toda tarefa que implemente rota, altere regra de negócio, mude contrato, resolva bug não-trivial ou tome decisão arquitetural adiciona entrada datada no **topo** de `docs/DECISIONS.md`. Sem entrada = tarefa incompleta.
2. **Geração obrigatória por CLI:** proibido criar manualmente do zero migrations, actions/handlers, jobs, workers, events, domains. Sempre `node scripts/generate.js <tipo> [args]`. Pode-se editar o gerado; a base vem do gerador.
3. **Poluição Zero:** temporários deletados antes da conclusão; rascunhos persistentes só em `/scratch/` (gitignored).
4. **Guardrails de Dependência:** nunca adicionar dependência de runtime sem consentimento explícito e prévio do humano. Exceção única: tooling da fundação (registrado no DECISIONS).
5. **Mudança de schema é evento de primeira classe:** nenhuma alteração de banco fora de migration gerada. Nada de ALTER manual.
6. **Pare-e-pergunte:** interromper e consultar o humano para violar Lei de Segurança, nova dependência, quebra de contrato público de domínio ou decisão arquitetural irreversível.
7. **Estado é de primeira classe — ler ANTES, atualizar DEPOIS:** antes de qualquer feature, ler `docs/STATUS.md`; se está ✅, abrir os arquivos apontados e partir do que existe — NUNCA reconstruir. Ao concluir, atualizar a linha do STATUS na MESMA tarefa, junto com a entrada no DECISIONS.

**1c. Padrões de Qualidade (transcrever):**
- `> 300` linhas líquidas de código (sem comentários/vazias) = warning; `> 500` = proibido (falha o verify-rules). Ao atingir: modularizar.
- Componentes visuais: acima de ~150 linhas ou mais de uma responsabilidade → extrair subcomponentes.
- Sem arquivos "Deus": types, schemas, regras e helpers em arquivos dedicados (`types.ts`, `schema.ts`, `utils.ts`).
- Responsabilidade Única: propósito declarável em uma frase; se precisa de "e", divida.
- Tipagem estrita; sem `any` sem justificativa.

**1d. Leis de Segurança (transcrever; detalhadas nos módulos 04, 06–08):**
1. Multi-tenant: toda tabela tem coluna de isolamento (`tenant_id`/`org_id`), salvo allowlist global.
2. RLS habilitada + ≥1 policy em toda tabela de tenant (ou isolamento equivalente na camada de adapters, com teste).
3. Credenciais privilegiadas (service role, admin clients, secrets) jamais em arquivo cliente.
4. `.env` gitignored; `.env.example` versionado; validação de env em boot; secret scanning no CI.
5. Menor privilégio: service-role só em código server-side isolado.

### 2. Ponteiros por ferramenta
Na raiz, contendo **apenas** a referência (uma verdade, N ponteiros — nunca doc duplicada que diverge):
- `CLAUDE.md` → conteúdo: `@AGENTS.md`
- `GEMINI.md` → conteúdo: `@AGENTS.md`
- (se aplicável à IDE usada) `.cursorrules`, `.windsurfrules` → `@AGENTS.md`

### 3. `docs/DECISIONS.md` + `docs/adr/`
Log vivo. Entradas no **topo**, formato:
```md
## [YYYY-MM-DD] <título curto da decisão>
- **Status:** accepted | superseded by #NNNN
- **Contexto:** que problema/força gerou a decisão
- **Decisão:** o que foi decidido
- **Arquivos impactados:** caminhos
- **Consequências / Gotchas:** trade-offs e armadilhas
```
Decisões estruturais maiores ganham ADR numerado em `docs/adr/NNNN-titulo.md` (Context / Decision / Consequences / Status). Crie **agora** `docs/adr/0001-bootstrap.md` registrando a adoção deste Dev OS, e a primeira entrada no `DECISIONS.md` apontando para ele (inclua as devDependencies de tooling instaladas no módulo 01, se houve).

### 4. `docs/STATUS.md` — mapa de estado por feature
**Problema que resolve:** DECISIONS é histórico e CONTEXT/skills ensinam *como* — nenhum responde de relance "o que está pronto vs. o que falta". Sem essa foto, um agente novo sugere reconstruir o que já funciona.

Template exato:
```md
# STATUS — o que está pronto, parcial ou a fazer
> LEIA ISTO PRIMEIRO (antes de propor/implementar qualquer feature).
> Estado por feature. Histórico do *porquê* fica em DECISIONS.md; visão do produto, no plano.
> Legenda: ✅ pronto/funcionando · 🟡 parcial · ⬜ a fazer · 🚫 fora de escopo
> Última auditoria: AAAA-MM-DD

| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
```

Regras de uso (documentar no próprio arquivo ou no AGENTS.md):
- **Greenfield:** começa quase tudo ⬜; feature concluída vira ✅ na MESMA tarefa (faz parte do DoD).
- **Brownfield:** a 1ª tarefa é AUDITAR o código (rotas/handlers/migrations + grep de integrações) e backfillar. ✅ só para o confirmado no código; na dúvida, 🟡/⬜ — STATUS impreciso é pior que ausente.
- **Granularidade:** uma linha por feature de usuário ou fluxo de negócio, não por arquivo.
- **Papéis:** STATUS = estado · DECISIONS = porquê · plano = produto · CONTEXT/skills = como. Não fundir.

## Regras invioláveis deste módulo
- AGENTS.md é a ÚNICA fonte; ponteiros não podem conter conteúdo próprio.
- As 9 seções do AGENTS.md na ordem exata; protocolo transcrito integral, não resumido.

## Critério de aceite
- [ ] `AGENTS.md` contém as 9 seções na ordem, com protocolo de 7 regras integral.
- [ ] `CLAUDE.md` e `GEMINI.md` contêm exatamente `@AGENTS.md`.
- [ ] `docs/STATUS.md`, `docs/DECISIONS.md` (com 1ª entrada) e `docs/adr/0001-bootstrap.md` existem.
- [ ] O ponteiro de primeira leitura para o STATUS está no topo do AGENTS.md.

## Ao concluir
1. Marcar ✅ na linha 02 do `MASTER-PLAN.md`.
2. Registrar a entrada no `DECISIONS.md` (esta é a primeira aplicação da regra 2.1).
3. PARAR. Não iniciar o módulo 03 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
