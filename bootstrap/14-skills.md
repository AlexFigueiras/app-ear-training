# Módulo 14 — Skills nativas de IA

## Depende de: 13

## Objetivo
Cada domínio/módulo crítico vira uma skill consumível por Claude e Gemini, sempre sincronizada com o `CONTEXT.md` local — sem documentação que diverge.

## Entregáveis obrigatórios

### 1. Estrutura de skills
- `.claude/skills/<skill>/SKILL.md` e `.gemini/skills/<skill>/SKILL.md` para cada domínio existente e para módulos críticos transversais que merecerem (`database`, `frontend`, `worker` — criar apenas os que têm CONTEXT/conteúdo real; não inventar skills vazias).
- Cada `SKILL.md` **inclui/importa** o conteúdo do `CONTEXT.md` correspondente + o frontmatter/cabeçalho que a ferramenta exigir (name, description de gatilho).

### 2. Sincronização garantida
- `generate sync-skills` (módulo 09) cobre todos os pares CONTEXT → SKILL existentes.
- Pre-commit (módulo 10) já roda o sync + `git add` — confirmar que os diretórios novos entram.
- Fluxo é **unidirecional**: edita-se o `CONTEXT.md`; SKILL.md é derivado. Documentar isso no cabeçalho gerado de cada SKILL.md ("ARQUIVO GERADO — edite o CONTEXT.md do domínio").

### 3. Mapa no AGENTS.md
Conferir que o Mapa de Contexto lista todos os domínios com seus CONTEXT.md (alimentado desde o módulo 09) e mencionar que as skills são derivadas deles.

## Regras invioláveis deste módulo
- Nenhum conteúdo escrito diretamente em SKILL.md — sempre derivado do CONTEXT.md.
- Uma skill por domínio/módulo crítico; sem skills genéricas duplicando o AGENTS.md.

## Critério de aceite
- [ ] Para cada `domains/*/CONTEXT.md` existe SKILL.md em `.claude/skills/` E `.gemini/skills/`.
- [ ] **Teste de sincronia:** editar uma linha de um CONTEXT.md → commit → SKILL.md correspondente atualizado no mesmo commit. Reverter a edição de teste.
- [ ] `generate sync-skills` rodado duas vezes seguidas → segunda execução sem diff (idempotência).

## Ao concluir
1. Marcar ✅ na linha 14 do `MASTER-PLAN.md`.
2. Entrada no `DECISIONS.md` se a lista de skills transversais foi além dos domínios.
3. PARAR. Não iniciar o módulo 15 nesta mesma resposta.

## Cláusula anti-simplificação
Nenhum item dos Entregáveis é opcional. Antes de encerrar, liste cada entregável e seu status. Se algo ficou de fora, o módulo NÃO está concluído.
