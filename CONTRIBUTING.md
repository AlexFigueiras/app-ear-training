# Contribuindo

Leia [`AGENTS.md`](AGENTS.md) primeiro — é a fonte única de verdade (protocolo, leis de
segurança, padrões de qualidade). Este arquivo cobre o fluxo prático de contribuição.

## Fluxo de trabalho

1. Crie uma branch a partir de `main`.
2. Leia `docs/STATUS.md` (não reconstrua o que já está ✅) e, se o domínio tiver skill em
   `.agent/skills/`, leia-a antes de mexer.
3. Faça as alterações.
4. Rode as travas locais (ver abaixo) antes de commitar.
5. Commit no formato [Conventional Commits](https://www.conventionalcommits.org/pt-br/):
   `tipo(escopo?): descrição`, tipos válidos: `feat|fix|chore|refactor|docs|test|perf|ci|build`.
   O hook `commit-msg` rejeita mensagens fora do padrão (ver "Ativando os hooks" abaixo).
6. Abra PR contra `main`. CI precisa ficar verde (`.github/workflows/ci.yml`) para poder ser
   mergeado — configure branch protection em `main` no GitHub se ainda não estiver ativo
   (pendência humana, ver `MASTER-PLAN.md` módulo 11).
7. Atualize `docs/STATUS.md` (linha da feature) e adicione entrada em `docs/DECISIONS.md` na
   MESMA tarefa que implementa/altera algo não-trivial.

## Ativando os hooks locais

`pub` não tem um lifecycle script equivalente ao `npm install`/`prepare`. Rode uma vez após
clonar:
```bash
git config core.hooksPath .githooks
```
Isso ativa `.githooks/pre-commit` (roda `dart run tool/verify_rules.dart`) e
`.githooks/commit-msg` (valida Conventional Commits). Os hooks são burláveis
(`git commit --no-verify`) — a trava real é o CI, que roda os mesmos checks de forma inescapável.

## O que as travas cobram

| Comando | O que verifica |
|---|---|
| `flutter analyze` | Erros e lints estáticos. **Hoje falha** por 2 erros pré-existentes em `lib/ui/screens/training_dashboard.dart` e `test/widget_test.dart` — ver `docs/STATUS.md`. |
| `dart format --set-exit-if-changed lib test tool` | Formatação. Non-blocking no CI por ora — 29/33 arquivos de `lib/` não estão formatados; reformatar é um item follow-up isolado (ver `docs/STATUS.md`), não corrigido neste bootstrap. |
| `flutter test` | Suíte de testes. Cobertura ainda não é enforced (débito registrado). |
| `dart run tool/verify_rules.dart` | Tamanho de arquivo (300 warn/500 fail, com catraca de baseline para legado) e segredos hard-coded em `lib/`. |

## Como adicionar uma feature hoje

Não há gerador de scaffolding (`generate`) neste projeto — ver `AGENTS.md` seção 2. Crie a tela
seguindo os padrões existentes em `lib/screens/` ou `lib/ui/screens/` (há uma duplicidade
conhecida entre as duas, ver `docs/STATUS.md` — não a amplie desnecessariamente). Para orientação
de para onde o código deveria migrar no longo prazo (sem fazer a migração agora), veja a
topologia-alvo em `docs/ARCHITECTURE.md`.

## Convenção `scratch/`

Rascunhos e arquivos temporários de agentes de IA vão em `/scratch/` (gitignored). Nunca deixe
temporários fora dali — "Poluição Zero" (`AGENTS.md`, Protocolo Multiagente, regra 3).

## Dependências

- Nunca adicione uma dependência de runtime (`pubspec.yaml` → `dependencies:`) sem aprovação
  humana explícita e registro em `docs/DECISIONS.md`.
- Tooling de fundação (linter, formatter) pode ser adicionado como `dev_dependency` com aviso +
  registro, mas prefira Dart puro quando possível — este bootstrap deliberadamente não introduziu
  Node/npm como novo runtime de tooling.
- `pubspec.lock` é sempre versionado; CI instala com `flutter pub get` sobre o lockfile commitado.

## O que NÃO fazer sem aprovação humana explícita

Ver `AGENTS.md`, Protocolo Multiagente, regra 6 — inclui violar uma Lei de Segurança (seção 7),
adicionar dependência de runtime, ou mover fisicamente a estrutura de `lib/` para a topologia
documentada em `docs/ARCHITECTURE.md`.
