# DECISIONS — histórico vivo de decisões
> Entradas no topo (mais recente primeiro). Estado do que existe fica em `docs/STATUS.md`.

## [2026-07-18] Bootstrap Dev OS concluído
- **Status:** accepted
- **Resumo:** os 17 módulos do kit `bootstrap/*.md` foram avaliados e traduzidos para Flutter/Dart
  (ver `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md`); os aplicáveis foram executados e verificados
  com evidência real (não apenas descrita) — ver checklist de completude ao final de
  `MASTER-PLAN.md`. Nenhum arquivo em `lib/`, `cpp/`, `android/`, `web/`, `windows/` foi alterado
  (um efeito colateral de CRLF/LF em `windows/flutter/generated_plugin_registrant.*`, causado por
  `flutter pub get`, foi revertido — ver entrada acima). Nenhuma dependência de runtime nova.
  Débitos descobertos e não corrigidos (por exigirem tocar `lib/`/`test/`, fora do escopo pedido)
  estão listados em `docs/STATUS.md`: 2 erros reais em `flutter analyze` pré-existentes, 29/33
  arquivos de `lib/` fora do padrão `dart format`, ausência de validação de env em boot e de
  logger estruturado, suíte de testes real inexistente, duplicidade `lib/screens/` vs
  `lib/ui/screens/`, e rotação pendente das chaves que estavam no `.env` commitado.
- **Arquivos impactados:** ver lista completa na entrada "[2026-07-18] Bootstrap Dev OS adaptado"
  abaixo.

## [2026-07-18] `flutter pub get` tocou windows/flutter/generated_plugin_registrant.* — revertido
- **Status:** accepted
- **Contexto:** rodar `flutter pub get` (necessário para validar `flutter analyze`/`flutter
  format` durante a auto-verificação do bootstrap) fez o Flutter regenerar
  `windows/flutter/generated_plugin_registrant.cc/.h` e `generated_plugins.cmake`. `git diff -w`
  confirmou que o conteúdo é idêntico — a diferença era só CRLF/LF (efeito colateral do Flutter
  regenerando esses arquivos no Windows).
- **Decisão:** revertidos com `git checkout --` para não deixar nenhum arquivo em `windows/`
  (estrutura nativa) marcado como alterado, honrando o pedido de não tocar em nada nativo/mobile.
- **Arquivos impactados:** `windows/flutter/generated_plugin_registrant.cc`,
  `windows/flutter/generated_plugin_registrant.h`, `windows/flutter/generated_plugins.cmake`
  (revertidos, sem mudança líquida).
- **Consequências / Gotchas:** qualquer dev/agente que rodar `flutter pub get` neste ambiente
  Windows pode ver esse mesmo diff de CRLF/LF aparecer de novo — é inofensivo (conteúdo idêntico),
  mas vale conferir com `git diff -w` antes de commitar por engano.

## [2026-07-18] Higiene de segredo: `.env` untracked do git, rotação pendente
- **Status:** accepted (parcial — pendência humana explícita)
- **Contexto:** auditoria do bootstrap encontrou `.env` versionado no git desde antes deste
  trabalho, contendo `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `GOOGLE_TTS_API_KEY` reais, fora do
  `.gitignore`. O CI já usa valores fictícios (`.env` dummy criado em runtime), então o `.env`
  real nunca precisou estar versionado.
- **Decisão:** adicionar `.env` ao `.gitignore` e remover do índice (`git rm --cached .env`),
  mantendo o arquivo local intacto (o app continua funcionando normalmente em dev, já que o
  asset é lido do disco, não do git). **Rotação das chaves expostas e avaliação de reescrever o
  histórico do git ficam como ação humana pendente — não foram feitas** (rotação exige acesso
  aos consoles do Supabase e do Google Cloud; reescrita de histórico é operação destrutiva que
  não deve ser feita sem pedido explícito).
- **Arquivos impactados:** `.gitignore`, índice do git (não o conteúdo local de `.env`).
- **Consequências / Gotchas:** enquanto a rotação não acontecer, as chaves antigas continuam
  válidas e recuperáveis pelo histórico do git (`git log -p -- .env`). Tratar como comprometidas.

## [2026-07-18] Bootstrap Dev OS adaptado (kit `bootstrap/*.md` traduzido para Flutter/Dart)
- **Status:** accepted
- **Contexto:** o repositório não tinha `AGENTS.md`/`CLAUDE.md`, hooks de git, CI rigoroso, nem
  estado de projeto centralizado. O usuário pediu análise de necessidade/viabilidade do kit
  `bootstrap/` (PROJECT OS v3, 17 módulos, escrito para SaaS multi-tenant Node/TS/Postgres) e,
  aprovada, sua execução — sem alterar código de app, stack, ou estrutura mobile/nativa.
- **Decisão:** adotar uma versão adaptada e podada do kit (ver
  `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md` para o veredito módulo a módulo). Resumo:
  - Aplicados quase diretos: 00 (manifest), 02 (context engine), 13 (governança), 14 (skills),
    15 (docs/onboarding), 16 (auto-verificação).
  - Adaptados para Dart puro (sem introduzir Node/npm como novo runtime de tooling): 01
    (repo-init), 06 (verify-rules), 10 (hooks), 11 (CI).
  - Documentação-only, sem migração física: 03 (topologia por domínio) — ver
    `docs/ARCHITECTURE.md`.
  - Adiados por exigirem tocar código de app (fora do escopo "não alterar código" pedido): 04
    (validação de env em boot), 05 (observabilidade/logger — reduzido), 12 (escrever a suíte de
    testes real).
  - Não aplicáveis a um app mobile client-only sem backend próprio no repo e sem multi-tenancy:
    07 (migrations/RLS por tenant — o pouco reaproveitável foi absorvido no 06), 08 (generate
    migration/action/seed), 09 (generate event/worker/domain — sync-skills absorvido manualmente
    no módulo 14).
- **Arquivos impactados:** `MASTER-PLAN.md`, `AGENTS.md`, `CLAUDE.md`, `docs/STATUS.md`,
  `docs/DECISIONS.md`, `docs/adr/0001-bootstrap.md`, `docs/ARCHITECTURE.md`, `.gitignore`,
  `.env.example`, `.editorconfig`, `tool/verify_rules.dart` e checks, `.githooks/pre-commit`,
  `.github/workflows/ci.yml`, `.github/dependabot.yml`, `CHANGELOG.md`, `README.md`,
  `CONTRIBUTING.md`, `docs/RUNBOOK.md`.
- **Consequências / Gotchas:** nenhuma dependência de runtime nova; nenhum arquivo em `lib/`,
  `cpp/`, `android/`, `web/`, `windows/` tocado. Débitos que o bootstrap **não** resolveu (env
  validation, logger estruturado, suíte de testes real, duplicidade `lib/screens/` vs
  `lib/ui/screens/`, rotação de segredos) ficam explicitamente registrados em `docs/STATUS.md`
  como itens follow-up que exigem aprovação humana antes de tocar código de produto.
