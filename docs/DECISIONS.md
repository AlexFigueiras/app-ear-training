# DECISIONS — histórico vivo de decisões
> Entradas no topo (mais recente primeiro). Estado do que existe fica em `docs/STATUS.md`.

## [2026-08-18] Monetização & Google Play Billing Compliance (Módulo 5)
- **Status:** accepted
- **Contexto:** o app usava referências e lógica de checkout do Stripe diretamente no app para liberar os Níveis 3 e 4, violando as políticas da Google Play Store para bens digitais e assinaturas in-app.
- **Decisão:**
  1. Desacoplado o `GatekeeperService` do Stripe, estruturando suporte a tiers de assinatura (`SubscriptionTier.free`, `pro`, `elite`) e produtos da Play Store (`bosyn_pro_monthly`, `bosyn_elite_annual`).
  2. Implementado método `restorePurchases()` para restauração de compras ativas.
  3. Redesenhado o Paywall da `HomeScreen` para cumprir os requisitos legais do Google Play (seletor de planos com preços formatados, transparência nas condições de cancelamento e botão de restauração).
  4. Adicionado teste unitário `test/gatekeeper_service_test.dart`.
- **Arquivos impactados:** `lib/services/gatekeeper_service.dart`, `lib/ui/screens/home_screen.dart`, `test/gatekeeper_service_test.dart`.
- **Status:** accepted
- **Contexto:** `training_dashboard.dart` continha 552 linhas de código monolítico (violando o teto estrito de 500 linhas do `verify_rules.dart`), concentrando lógica de animação CustomPainter, cálculo e renderização de SNR, barra de progresso de energia neural e botões industriais.
- **Decisão:**
  1. Extraído `SonarDisplay` e `SonarPainter` para `lib/ui/widgets/sonar_display.dart`.
  2. Extraído `SNRMeter` para `lib/ui/widgets/snr_meter.dart`.
  3. Extraído `NeuralEnergyBar` para `lib/ui/widgets/neural_energy_bar.dart`.
  4. Extraído `IndustrialButton` para `lib/ui/widgets/industrial_button.dart`.
  5. Refatorado `training_dashboard.dart` para consumir os novos widgets modulares, reduzindo o arquivo para 380 linhas (100% dentro dos limites de qualidade).
- **Arquivos impactados:** `lib/ui/widgets/sonar_display.dart`, `lib/ui/widgets/snr_meter.dart`, `lib/ui/widgets/neural_energy_bar.dart`, `lib/ui/widgets/industrial_button.dart`, `lib/ui/screens/training_dashboard.dart`.
- **Status:** accepted
- **Contexto:** o app dependia de requisições HTTP síncronas para a API do Google Cloud TTS para sintetizar estímulos de fala nos treinos dos Níveis 2, 3 e 4. Em situações offline, sem internet, ou sem chave de API, a chamada lançava exceção e travava a sessão clínica. Além disso, o cache ficava na pasta temporária volátil e a pasta `assets/audio/` declarada no `pubspec.yaml` não existia fisicamente.
- **Decisão:**
  1. Criado diretório persistente `assets/audio/.gitkeep`.
  2. Implementado cache permanente de arquivos WAV em `getApplicationDocumentsDirectory()/bosyn_audio_cache/`.
  3. Adicionado gerador autônomo de áudio WAV 16-bit PCM Linear 48kHz mono em `GoogleTTSService` (com envelope anti-click e formantes acústicos harmônicos) que assume a síntese automaticamente caso a API online esteja indisponível ou sem chave.
  4. Endurecido o método `_convertInt16ToFloat32` no `AudioRehabEngine` para leitura segura de ByteData sem risco de estouro de buffer.
  5. Adicionado teste unitário `test/tts_service_test.dart` validando geração e cache offline.
- **Arquivos impactados:** `lib/services/tts_service.dart`, `lib/audio_engine/audio_engine.dart`, `assets/audio/.gitkeep`, `test/tts_service_test.dart`.
- **Status:** accepted
- **Contexto:** auditoria geral para publicação na Google Play Store identificou 7 bloqueadores críticos: `applicationId` inválido (`com.example.ear_training`), 2 erros de compilação pré-existentes (`remainingRestTime` ausente e `widget_test.dart` com referência quebrada), solicitação indevida de permissão de microfone (`RECORD_AUDIO`) sem uso real no app com bloqueio do usuário na Home, falta de alinhamento ELF de 16 KB na biblioteca C++ para Android 15+, ausência de regras Proguard/R8 para JNI/FFI, falta de configuração de assinatura de release e ausência de disclaimer clínico exigido pela Google Play Health Apps Policy.
- **Decisão:**
  1. Definido `applicationId = "com.bosyn.eartraining"` e `namespace = "com.bosyn.eartraining"`; criado `MainActivity.kt` no novo pacote.
  2. Adicionado `-Wl,-z,max-page-size=16384` no `cpp/CMakeLists.txt` (alinhamento obrigatório de 16 KB para Android 15).
  3. Criado `android/app/proguard-rules.pro` protegendo classes JNI de Oboe, Dart FFI e modelos de serialização.
  4. Criado `android/key.properties.example` e configurado `build.gradle.kts` para suportar assinatura de release condicional com fallback para debug.
  5. Saneado `AndroidManifest.xml` (removidos `RECORD_AUDIO`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN` e requisito de microfone).
  6. Removido o guardião de permissão artificial da `HomeScreen` (o app só reproduz áudio, nunca grava).
  7. Adicionado o getter `remainingRestTime` (Duration) no `GamificationController`, resolvendo o erro de compilação em `training_dashboard.dart`.
  8. Corrigido `test/widget_test.dart` para suíte unitária de `GamificationController`.
  9. Inserido card de Aviso de Saúde (Disclaimer Clínico) na `OnboardingScreen` em conformidade com as diretrizes do Google Play.
- **Arquivos impactados:** `lib/core/gamification_controller.dart`, `test/widget_test.dart`, `lib/ui/screens/home_screen.dart`, `lib/ui/screens/onboarding_screen.dart`, `lib/main.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/bosyn/eartraining/MainActivity.kt`, `android/app/proguard-rules.pro`, `android/key.properties.example`, `cpp/CMakeLists.txt`.
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
