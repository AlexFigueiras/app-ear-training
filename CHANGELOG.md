# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/). Este projeto
segue [Conventional Commits](https://www.conventionalcommits.org/pt-br/) — o `commit-msg` hook
(`.githooks/commit-msg`) valida o formato de cada commit.

> Mantido manualmente por ora. O kit original (`bootstrap/13-governanca.md`) recomenda uma
> ferramenta automática (Changesets/semantic-release/git-cliff); nenhuma foi introduzida neste
> bootstrap para não adicionar dependência de runtime/tooling sem necessidade imediata — ver
> `docs/DECISIONS.md`.

## [Unreleased]

### Added
- Fundação de governança Dev OS (adaptada de `bootstrap/*.md` para Flutter/Dart): `AGENTS.md`,
  `MASTER-PLAN.md`, `docs/STATUS.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md`,
  `tool/verify_rules.dart`, hooks versionados (`.githooks/`), CI endurecido, `CHANGELOG.md`,
  `.github/dependabot.yml`, `README.md`/`CONTRIBUTING.md`/`docs/RUNBOOK.md` reescritos.

### Security
- `.env` removido do índice do git (untracked) e adicionado ao `.gitignore`. Rotação das chaves
  expostas (Supabase, Google TTS) segue pendente — ver `docs/DECISIONS.md`.
