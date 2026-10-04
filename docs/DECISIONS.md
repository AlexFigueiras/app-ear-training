# DECISIONS — histórico vivo de decisões
> Entradas no topo (mais recente primeiro). Estado do que existe fica em `docs/STATUS.md`.

## [2026-10-04] Entrada e conta revisadas pela auditoria de UX (etapa A)
- **Status:** accepted (código); a recuperação de senha depende de ajuste no modelo de e-mail
- **Contexto:** a auditoria de UX da jornada do paciente (artifact "Auditoria UX BOSYN",
  commit 4b802e9, testada com Playwright) apontou na entrada: erros como exceção técnica em
  inglês e caixa alta (A1), cadastro sem próximo passo claro (A2), linguagem de terminal,
  campos sem nome acessível, sem autofill e sem "Esqueci minha senha" (A4). A2, A3 (perfil por
  trigger), A5 (rótulo "BOSYN") e A6 (tela de Conta) já tinham sido tratados pela revisão de
  prontidão para a Play, logo abaixo.
- **Decisões:**
  - Mensagens em `lib/core/auth_messages.dart` (Dart puro, testado): cada código do Supabase
    vira uma frase em pt-BR que diz o que fazer e aponta o campo; código desconhecido vira
    mensagem genérica, nunca o texto técnico.
  - Erros aparecem no próprio campo (`errorText`) e avisos num banner anunciado ao leitor de
    tela (`liveRegion`), em vez de snackbar em caixa alta de 10 px.
  - Campos com `labelText` (nome acessível), `autofillHints`, teclado de e-mail e botão de
    mostrar senha; textos com pelo menos 14 px e cores com contraste conferido (AA).
  - Confirmação de e-mail pendente: aviso explícito e "Reenviar e-mail de confirmação"
    (`auth.resend`), também quando o login falha por e-mail não confirmado.
  - "Esqueci minha senha" por **código de 6 dígitos** (`resetPasswordForEmail` →
    `verifyOTP(type: recovery)` → `updateUser`), não por link: o app não tem deep link, e o
    código funciona com o e-mail aberto em outro aparelho. Alternativa descartada por ora:
    deep link `com.bosyn.app://` (exige intent-filter, lista de redirects no Supabase e tela
    de nova senha disparada por evento). Exige `{{ .Token }}` no modelo "Reset Password".
  - A senha deixou de passar por `trim()` (espaços fazem parte da senha).
  - Visual mantido na direção atual (escuro, verde): qual guia vale para o app — o
    `docs/MASTER_PLAN.md` ou o design system "Ecossistema BOSYN" — segue como decisão do
    produto (achado H1).
- **Verificação:** `flutter analyze` sem avisos nos arquivos novos; `dart tool/verify_rules.dart`
  passa; `test/auth_messages_test.dart` e `test/auth_screen_test.dart` (12 testes) passam numa
  cópia sem `device_info_plus` (esta máquina não compila o `win32`); jornada completa (erro de
  senha, cadastro, reenvio, não confirmado, recuperação com código errado e certo) conferida no
  navegador com Supabase simulado, em 412×915, 360×640 e fonte 200%.

## [2026-10-04] Prontidão para a Google Play e endurecimento de segurança
- **Status:** accepted (código); ativação depende de ações humanas listadas abaixo
- **Contexto:** pedido do usuário: "o sistema está pronto para a Play Store? Pesquise os
  requisitos e ajuste; depois veja a segurança com base nas melhores práticas". Requisitos da
  Play e práticas de segurança foram pesquisados em fontes oficiais nesta data (lista em
  `docs/PLAY_STORE.md`). A auditoria encontrou bloqueadores de loja e falhas reais de segurança,
  detalhadas em `docs/SECURITY_REVIEW.md`. Os mais graves:
  - qualquer usuário se dava o PRO por um UPDATE do próprio app;
  - a chave do Google TTS era empacotada no APK;
  - o repositório é público com chaves reais no histórico.
- **Decisões:**
  - **Android:**
    - pacote `com.bosyn.app`, que vira definitivo no 1º upload — confirmar antes;
    - assinatura via `android/key.properties`, com o build do AAB bloqueado sem ele;
    - `targetSdk 36` fixado e `compileSdk ≥ 36`;
    - flags de 16 KB no CMake;
    - `allowBackup=false` + `dataExtractionRules`;
    - `network_security_config` só HTTPS (HTTP local apenas em debug);
    - label "BOSYN";
    - símbolos nativos no AAB.
  - **Permissões:** `RECORD_AUDIO` e `BLUETOOTH_*` removidas, junto com a tela que bloqueava o
    app sem elas. Nada no código (Dart ou C++) grava áudio ou usa APIs de Bluetooth; a
    detecção de fone usa `AudioManager.getDevices()`, que não pede permissão.
  - **Configuração:** `flutter_dotenv` (`.env` como asset) trocado por
    `--dart-define-from-file=.env`, com validação fail-fast (`lib/core/app_config.dart`), o que
    fecha o módulo 04. Motivo além da dependência a menos: com o asset, *qualquer* chave
    deixada no `.env` local do desenvolvedor ia para o APK; com dart-define, só as variáveis
    lidas pelo código entram no binário.
  - **Supabase:** `supabase_flutter` sobe de 2.12 para 2.18 (mesma dependência, restrição
    `^2.13.0`) para usar `publishableKey`, porque as chaves legadas `anon` serão desligadas no
    fim de 2026. A variável passa a se chamar `SUPABASE_PUBLISHABLE_KEY`, com
    `SUPABASE_ANON_KEY` aceito como nome antigo.
  - **TTS:** a chamada passa por uma Edge Function autenticada (`supabase/functions/tts`) e a
    chave do Google fica só nos secrets dela. Foi preferido a pré-gerar os áudios porque
    mantém o comportamento atual sem um passo de build novo.
  - **Exclusão de conta** (exigência da Play + LGPD art. 18):
    - tela Conta e Privacidade, com reautenticação por senha (MASVS-AUTH-3);
    - Edge Function `delete-account` com `auth.admin.deleteUser`, o id vindo do JWT;
    - `ON DELETE CASCADE` na migration 003.
    - Foi preferida a uma RPC `SECURITY DEFINER`, que o Security Advisor do Supabase sinaliza.
  - **Paywall:** o checkout falso (esperava 2 s e gravava `pro` pelo cliente) e o
    `upgradeToPro()` foram removidos; o PRO aparece como "em breve". Vender recurso digital
    exige Google Play Billing (Stripe sozinho viola a política) e a integração depende de
    decisão de produto e de dependência nova. `flutter_stripe` saiu por não ser usado em lugar
    nenhum.
  - **Banco** (`supabase_migration_003_security.sql`):
    - `profiles` versionada;
    - trigger impede o cliente de mudar o plano;
    - trigger de cadastro cria o perfil (nunca bloqueia o signup);
    - FKs para `auth.users` com cascade;
    - políticas RLS canônicas (`TO authenticated`, `(select auth.uid())`), que **substituem**
      as existentes;
    - `anon` sem acesso às tabelas clínicas.
  - **LGPD/Play:**
    - política de privacidade em `docs/legal/`: o mesmo arquivo é asset do app e página web,
      sem cópia;
    - página web de exclusão de conta;
    - consentimento específico (checkbox não pré-marcado) gravado com a versão da política
      nos metadados do usuário;
    - aviso de saúde no onboarding, no cadastro e na conta.
  - **Correções colaterais necessárias:**
    - arquivo de telemetria offline passa a ter dono (antes subia na conta de quem estivesse
      logado);
    - estado de gamificação zerado no logout;
    - placeholders "Palavra1/Falsa1" fora do sorteio de estímulos — a TTS falaria "Palavra um"
      ao paciente. Mudança de conteúdo clínico mínima: só exclui itens que não são palavras;
    - `print` → `debugPrint`, desligado em release (dado clínico fora do logcat);
    - os 2 erros de `flutter analyze` corrigidos.
  - **Automação:**
    - `check-release-config` no `verify_rules` (bloqueia `.env` como asset, `com.example`,
      release com chave debug e backup ligado), testado contra a config antiga;
    - job de CI `release-check` (APK release ofuscado + `zipalign -P 16` +
      `tool/check_elf_alignment.dart`).
- **Dependências:** nenhuma de runtime adicionada. Removidas: `flutter_dotenv`, `flutter_stripe`,
  `permission_handler`, `http` (este segue transitivo via Supabase). Atualizada:
  `supabase_flutter`.
- **Arquivos impactados:**
  - `android/`: `app/build.gradle.kts`, `AndroidManifest.xml`, `res/xml/*`, `MainActivity.kt`
    movido para `com/bosyn/app`;
  - `cpp/CMakeLists.txt`, `pubspec.yaml`/`pubspec.lock`;
  - `lib/`: `main.dart`, `core/app_config.dart`, `core/legal_documents.dart`,
    `core/gamification_controller.dart`, `services/*`, `ui/screens/*`,
    `audio_engine/audio_engine.dart`;
  - `test/*`, `tool/check_elf_alignment.dart`, `tool/checks/check_release_config.dart`,
    `tool/verify_rules.dart`;
  - `supabase/functions/*`, `supabase_migration_003_security.sql`;
  - `docs/legal/*`, `docs/PLAY_STORE.md`, `docs/SECURITY_REVIEW.md`, `.env.example`,
    `.vscode/launch.json`, `.github/workflows/ci.yml`;
  - governança: STATUS, RUNBOOK, CHANGELOG, MASTER-PLAN, AGENTS.md, README.
- **Pendências humanas (sem elas o app não deve ir para produção):**
  - rotacionar as chaves (repo público);
  - aplicar a migration 003;
  - publicar as 2 Edge Functions + secret `GOOGLE_TTS_API_KEY`;
  - ajustar o Auth do Supabase;
  - preencher os `[PREENCHER]` e publicar as páginas legais;
  - criar a keystore de upload;
  - trocar o ícone;
  - confirmar conta de organização (apps médicos);
  - revisão regulatória (ANVISA RDC 657/2022) e jurídica.
- **Consequências / Gotchas:**
  - `flutter run` sem `--dart-define-from-file=.env` abre na tela de configuração inválida (de
    propósito). Os `launch.json` do VS Code já passam o arquivo.
  - Sem a Edge Function `tts` publicada, os treinos ficam sem áudio.
  - A migration 003 **apaga e recria** as políticas das 6 tabelas clínicas.
  - Nada disto foi verificado com build Android ou `flutter test` nesta máquina (sem Android
    SDK e sem compilador C); a prova fica no CI.
  - Existem branches `claude/*` não mesclados (12–25 commits, jun/2026) que tocam os mesmos
    arquivos — ver `docs/STATUS.md`.

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
