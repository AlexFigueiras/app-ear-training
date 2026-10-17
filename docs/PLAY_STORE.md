# Publicação na Google Play — BOSYN

> Levantamento de requisitos em 2026-10-04 (fontes oficiais ao final), atualizado em 2026-10-17
> com a assinatura PRO pelo Google Play Billing, os anúncios do AdMob e os botões de build no
> GitHub (skill "publicar na Play Store", adaptada). Diário das missões: `PROGRESSO.md`. Textos da
> loja: `docs/play-store/ficha-da-loja.md`. Respostas com botão Copiar: Folha de Respostas
> (https://claude.ai/artifact/KynF31YyaytfpXmA47wYD7, privada; fonte em
> `docs/play-store/folha-de-respostas.html`). Estado do código: `docs/STATUS.md`; porquês:
> `docs/DECISIONS.md`; segurança: `docs/SECURITY_REVIEW.md`.

## Veredito

**O código está pronto para o teste interno; a produção ainda depende de você.** O que falta é
conta, chave, console e revisão jurídica (seção 2). Três itens podem impedir a publicação mesmo
com o app perfeito:

1. **Tipo de conta de desenvolvedor.** A Play classifica "cuidados auditivos" e "reabilitação"
   como apps **médicos**, e apps médicos exigem **conta de organização** (com D-U-N-S). A conta da
   BOSYN é de organização e já está liberada: este item está resolvido.
2. **Enquadramento regulatório.** O app faz um teste de limiar auditivo. A Play exige o aviso "não
   é dispositivo médico" para quem não tem registro. Confirme o posicionamento com um
   especialista (ANVISA, RDC 657/2022 — software como dispositivo médico) antes da produção.
3. **Chaves vazadas.** O repositório é público e o histórico do git contém o `.env` antigo com
   chaves reais. Rotacione as chaves antes de qualquer build de produção.

## 1. Requisitos técnicos — estado no código

| Requisito da Play | Estado | Onde |
|---|---|---|
| Target API 36 (obrigatório desde 31/08/2026) | ✅ `targetSdk = 36`, `compileSdk ≥ 36` | `android/app/build.gradle.kts` |
| Páginas de 16 KB (apps com código nativo) | ✅ conferido no APK e no AAB a cada push | `cpp/CMakeLists.txt`, job `release-check` |
| AAB assinado com chave de upload (nunca a debug) | ✅ `android/key.properties`; o AAB não sai sem ele | `android/app/build.gradle.kts`, `tool/play/` |
| Pacote definitivo | ✅ `com.bosyn.app` — **não muda depois do 1º envio** | idem |
| Nome no aparelho e ícone próprio | ✅ "BOSYN", ícone adaptativo com camada monocromática | `android/app/src/main/res/` |
| Só as permissões necessárias | ✅ sem microfone e Bluetooth; BILLING, AD_ID e ACCESS_NETWORK_STATE vêm das bibliotecas | `AndroidManifest.xml` |
| Exclusão de conta dentro do app e na web | ✅ no app; página web gerada por `tool/legal_html.dart` | `account_screen.dart`, `docs/legal/` |
| Política de privacidade dentro do app | ✅ mesmo arquivo da web (versão 2026-10-17) | `docs/legal/politica-de-privacidade.md` |
| Aviso de saúde e consentimento para dado de saúde | ✅ onboarding, cadastro e conta | `lib/core/legal_documents.dart`, `auth_screen.dart` |
| Nenhum segredo dentro do APK | ✅ TTS e compra conferidos em Edge Functions | `supabase/functions/` |
| Assinatura pelo Google Play Billing (Billing Library 8+) | ✅ `in_app_purchase` 3.3 (Billing 8.0); plano gravado só pelo servidor | `lib/services/billing_service.dart`, `play-subscription` |
| Folha da assinatura com preço, período, renovação e cancelamento | ✅ | `lib/ui/screens/pro_offer_sheet.dart` |
| Anúncios com consentimento (UE/Reino Unido) e sem clique acidental | ✅ UMP; banner só na Home com folga; vídeo só por escolha | `lib/services/ads_service.dart` |
| Teste em tablet/dobrável (Android 16 ignora trava de orientação em telas ≥ 600 dp) | ⬜ | — |

## 2. O que você precisa fazer, em ordem

A ordem detalhada, com o que já foi feito, fica no `PROGRESSO.md`. Resumo:

1. **Juntar o código no `main`.** Os botões do GitHub só aparecem em **Actions** quando os
   workflows estão no branch padrão. Mescle `claude/treino-eficaz` (depois do checklist no
   celular) e esta branch (`claude/gracious-hopper-qmnsfs`, que já contém a outra).
2. **Rotacionar as chaves expostas** (`docs/SECURITY_REVIEW.md`, item C1).
3. **Supabase:** aplicar as migrations `supabase_migration_003_security.sql` e
   `supabase_migration_004_play_billing.sql`; publicar as Edge Functions (seção 5.3); ajustar o
   Auth (confirmação de e-mail, senha mínima 8, SMTP próprio, `{{ .Token }}` no e-mail "Reset
   Password").
4. **Chave de upload e primeiro AAB de teste** (seção 3).
5. **AdMob:** app + 2 blocos + 3 segredos (seção 5.4).
6. **Textos legais:** preencher os `[PREENCHER]` de `docs/legal/`, revisar com um advogado e
   publicar as duas páginas no site (seção 6).
7. **Play Console:** criar o app, responder "Conteúdo do app" (seção 4), página da loja
   (`docs/play-store/ficha-da-loja.md`).
8. **Teste interno:** instalar pela Play, fazer o checklist no celular, criar as assinaturas e
   testar a compra com testador de licença (seção 5.2).
9. **Produção:** AAB com anúncios **reais**, enviar para revisão.

## 3. Gerar o AAB (botões do GitHub)

O AAB é montado na nuvem do GitHub: não precisa de Android SDK no computador.

| Botão (aba Actions) | O que faz |
|---|---|
| **1 - Criar chave de upload (só uma vez)** | cria a chave PKCS12 (alias `upload`). Só roda com o repositório **Private** |
| **2 - Gerar AAB para a Play Store** | gera o `.aab` assinado; escolha **teste** (teste interno) ou **reais** (produção) |

Use sempre **Run workflow**. O **Re-run** repete o número da versão, e a Play recusa número
repetido. O número sobe sozinho (`run_number` + a variável opcional `VERSION_OFFSET`); o nome da
versão vem do `pubspec.yaml` (`version: 1.0.0+…` → "1.0.0").

### 3.1 A chave de upload (uma vez)

O repositório é **público**: em repositório público, qualquer pessoa logada no GitHub baixa os
Artifacts de uma execução. Por isso o botão 1 se recusa a rodar. Escolha um caminho:

- **A. Deixar o repositório Private** (recomendado também por causa das chaves no histórico).
  Depois: segredo `KEYSTORE_PASSWORD` (12+ caracteres, **sem acento nem ç**: o Java recusa) →
  botão 1 → baixar o pacote **chave-de-upload** → segredo `KEYSTORE_BASE64` com todo o texto de
  `KEYSTORE_BASE64.txt` → apagar o pacote em Artifacts.
- **B. Criar no computador** (precisa de um JDK, por exemplo o Temurin 17). No PowerShell:

  ```powershell
  keytool -genkeypair -v -storetype PKCS12 -keystore bosyn-upload.jks -alias upload `
    -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=BOSYN, O=BOSYN, C=BR"
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("bosyn-upload.jks")) | Set-Content -NoNewline KEYSTORE_BASE64.txt
  ```

  Cadastre os segredos `KEYSTORE_PASSWORD` (a senha digitada) e `KEYSTORE_BASE64` (o texto do
  arquivo).

Nos dois caminhos, guarde `bosyn-upload.jks`, o `.txt` e a senha em **dois lugares seguros**
(ex.: Drive e pendrive) e nunca mande para ninguém. Se a chave se perder, a Play Console troca a
chave de upload (Integridade do app), mas leva dias.

### 3.2 Segredos e variáveis (Settings → Secrets and variables → Actions)

| Nome | Tipo | O que é |
|---|---|---|
| `KEYSTORE_BASE64` | segredo | texto de `KEYSTORE_BASE64.txt` |
| `KEYSTORE_PASSWORD` | segredo | senha da chave de upload |
| `SUPABASE_URL` | segredo | `https://<projeto>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | segredo | chave `sb_publishable_…` (o botão recusa chave secreta) |
| `ADMOB_APP_ID` | segredo | ID do app BOSYN no AdMob (tem `~`) — só para **reais** |
| `ADMOB_BANNER_ID` | segredo | bloco "Banner Home" (tem `/`) — só para **reais** |
| `ADMOB_REWARD_ID` | segredo | bloco "Vídeo sessão PRO" (tem `/`) — só para **reais** |
| `VERSION_OFFSET` | variável (opcional) | soma ao número da versão (ex.: 100) se o workflow mudar de nome |
| `KEY_ALIAS` | variável (opcional) | nome da chave, se o keystore tiver mais de uma |

Os IDs do AdMob e a chave publishable não são senhas (vão dentro do app); ficam como segredos só
para o build buscar num lugar só.

### 3.3 O que o botão 2 confere

- Chave e senha combinam; o AAB sai assinado com a chave de upload, nunca a debug.
- Supabase com `https` e chave pública (recusa `sb_secret_` e JWT `service_role`).
- **reais:** os 3 IDs do AdMob no formato certo (`~` no app, `/` nos blocos), da mesma conta,
  banner ≠ vídeo, sem IDs de teste; política sem `[PREENCHER]` (ela aparece dentro do app).
- **teste:** usa os IDs de teste do Google (anúncio "Test Ad"), sem risco para a conta do AdMob.
- No AAB pronto: ID do AdMob certo no manifesto, permissão BILLING e bibliotecas nativas em 16 KB.
- Resumo da execução: versão, tipo de anúncio, impressões digitais SHA-1/SHA-256 da chave.
- Artifacts: `bosyn-vN-anuncios-TESTE|REAIS` (o `.aab`, 30 dias) e `…-simbolos-dart` (90 dias).
  **Guarde os símbolos de cada versão enviada**: sem eles não dá para ler os relatórios de erro
  ofuscados (`flutter symbolize`).

O CI faz o mesmo build e a mesma conferência a cada push, com uma chave descartável (job
`release-check`, passo "Ensaio do AAB").

## 4. Formulários do Play Console ("Conteúdo do app")

Antes de cada formulário, tire um print: as telas mudam com o tempo; use as respostas abaixo como
guia e confira as opções reais. A Folha de Respostas tem tudo isto com botão Copiar.

| Formulário | Resposta |
|---|---|
| Criar app | Nome "BOSYN: Treino Auditivo"; idioma pt-BR; **App**; **Sem custo financeiro** (o app é gratuito com compras no app) |
| Política de privacidade | https://alexfigueiras.github.io/politica-bosyn.html |
| Acesso ao app | **Algumas funções exigem login**: informe e-mail e senha de uma conta só para a revisão (e-mail confirmado). Dê PRO a ela pelo SQL (abaixo) para o revisor ver tudo |
| Anúncios | **Sim, meu app contém anúncios** |
| Classificação de conteúdo | Categoria "Todos os outros tipos de app" (utilitário/produtividade/outro). Tudo **Não**, menos **Compras digitais: Sim** (assinatura). Vídeo premiado não conta como compra |
| Público-alvo | **18 anos ou mais**. Faixas abaixo de 13 ativam a política de Famílias |
| Apps de saúde | Marque as categorias de saúde que correspondem (treino auditivo / cuidados auditivos). É grupo médico: exige conta de organização (a da BOSYN é) |
| ID de publicidade | **Sim**: Publicidade ou marketing, Análise, Prevenção de fraudes, segurança e conformidade (o SDK do AdMob declara `AD_ID`) |
| Recursos financeiros | **Meu app não oferece recursos financeiros** |
| Apps governamentais | **Não** |
| Exclusão de conta | https://alexfigueiras.github.io/exclusao-de-conta-bosyn.html |
| Segurança dos dados | Tabela abaixo |

Conta para a revisão (no SQL Editor do Supabase, depois de criar a conta pelo app):

```sql
update public.profiles set subscription_status = 'elite'
 where user_id = (select id from auth.users where email = '<e-mail da conta de revisão>');
```

**Segurança dos dados**, com base no que o código coleta hoje:

| Categoria (Play) | Coletado | Compartilhado | Finalidade | Obrigatório |
|---|---|---|---|---|
| Informações pessoais → Endereço de e-mail | Sim | Não | Gerenciamento da conta | Sim |
| Informações pessoais → IDs do usuário | Sim (id da conta) | Não | Gerenciamento da conta, funcionalidade | Sim |
| Saúde e condicionamento físico → Informações de saúde | Sim (teste auditivo, resultados do treino) | Não | Funcionalidade do app | Sim |
| Informações financeiras → Histórico de compras | Sim (token, plano, validade) | Não | Funcionalidade do app (assinatura) | Não (só de quem assina) |
| Atividade no app → Interações com o app | Sim (respostas e progresso; e o SDK do AdMob) | Sim (AdMob) | Funcionalidade, Análise, Publicidade, Prevenção de fraudes | Sim |
| Local → Local aproximado | Sim (IP, pelo SDK do AdMob) | Sim (AdMob) | Publicidade, Análise, Prevenção de fraudes | Sim |
| Identificadores do dispositivo → ID do dispositivo ou outros IDs | Sim (ID de publicidade, pelo SDK) | Sim (AdMob) | Publicidade, Análise, Prevenção de fraudes | Sim |
| Informações e desempenho do app → Registros de falhas e Diagnóstico | Sim (pelo SDK do AdMob) | Sim (AdMob) | Análise, Prevenção de fraudes | Sim |
| Áudio, localização precisa, contatos, fotos | Não coletados | — | — | — |

- Dados criptografados em trânsito: **sim**. Processamento efêmero: **não**.
- Criação de conta: **sim, com e-mail e senha**. Login com conta externa: **não**.
- Pedido de exclusão: **sim** (no app e pela página web).
- Fornecedores que atuam em seu nome (Supabase) não contam como compartilhamento. O Google TTS
  recebe só a palavra a ser falada. O SDK do AdMob conta como compartilhamento (terceiro com
  finalidade própria) e só é ligado no plano grátis.
- Se o app mudar (por exemplo, com analytics), atualize o formulário antes de publicar.

**Descrição da loja.** A Play exige que a descrição diga que o app "não é um dispositivo médico e
não diagnostica, trata, cura nem previne doenças", recomende procurar um profissional, avise que
é preciso usar **fones de ouvido** e não prometa resultado clínico. O texto pronto está em
`docs/play-store/ficha-da-loja.md`.

## 5. Monetização: assinatura PRO ou vídeo

### 5.1 Como funciona

- **Grátis:** "Palavras parecidas", teste de audição e medida de progresso. Banner do AdMob só no
  rodapé da tela inicial.
- **PRO (assinatura mensal ou anual pelo Google Play):** todos os treinos, sem anúncios.
- **Sessão por vídeo:** quem não assina libera 1 sessão de um treino PRO assistindo a um vídeo
  premiado, até 2 por dia (`MonetizationConfig.rewardedSessionsPerDay`).
- Nunca há anúncio durante o teste de audição ou um treino: o som de um anúncio atrapalharia o
  exercício.
- Anúncios **não personalizados** (o app trata dado de saúde) e conteúdo limitado a "PG".
- O app nunca decide o plano: cada compra vai para a Edge Function `play-subscription`, que
  confere o token na Google Play Developer API, grava o plano com a chave secreta (o trigger da
  migration 004 ignora qualquer tentativa do app) e confirma a compra. A `play-rtdn` recebe as
  notificações da Play (renovação, cancelamento, suspensão, reembolso). Um token só libera o PRO
  para uma conta.

### 5.2 Play Console

1. **Monetizar → Configuração de monetização:** perfil de pagamentos da BOSYN.
2. Envie antes um AAB para o **teste interno**: a Play só deixa criar assinatura depois que um
   pacote com a permissão BILLING foi enviado.
3. **Monetizar → Produtos → Assinaturas → Criar assinatura**, uma de cada vez:

   | ID do produto | Nome | Plano base (ID) | Período | Renovação |
   |---|---|---|---|---|
   | `bosyn_pro_mensal` | BOSYN PRO mensal | `mensal` | 1 mês | automática |
   | `bosyn_pro_anual` | BOSYN PRO anual | `anual` | 1 ano | automática |

   Defina o preço de cada plano e **ative** os dois planos base. Não crie oferta de teste grátis
   por enquanto: o app mostra o preço do plano base.
4. **Configurações → Teste de licença:** adicione os Gmails da equipe. As compras deles não são
   cobradas e renovam em minutos.
5. **Usuários e permissões → Convidar usuário:** o e-mail da conta de serviço (5.3) com
   permissão no app BOSYN para **Ver informações financeiras** e **Gerenciar pedidos e
   assinaturas**.

### 5.3 Google Cloud e Supabase

1. No Google Cloud (projeto da BOSYN), ative a **Google Play Android Developer API**, crie uma
   **conta de serviço** e uma chave JSON. Não faça commit dela.
2. Secrets das Edge Functions:

   ```bash
   supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT="$(cat conta-de-servico.json)" --project-ref <ref>
   supabase secrets set PLAY_RTDN_TOKEN=<texto aleatório com 32+ caracteres> --project-ref <ref>
   # opcionais: PLAY_PACKAGE_NAME (padrão com.bosyn.app) e PLAY_SUBSCRIPTION_IDS
   # (padrão bosyn_pro_mensal,bosyn_pro_anual)
   ```

3. Publique as funções:

   ```bash
   supabase functions deploy tts --project-ref <ref>
   supabase functions deploy delete-account --project-ref <ref>
   supabase functions deploy play-subscription --project-ref <ref>
   supabase functions deploy play-rtdn --no-verify-jwt --project-ref <ref>
   ```

4. **Notificações em tempo real (RTDN):** no Pub/Sub, crie o tópico `play-rtdn` e dê o papel
   **Publicador do Pub/Sub** a `google-play-developer-notifications@system.gserviceaccount.com`.
   Crie uma assinatura **push** para
   `https://<ref>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>`. Na Play Console
   (Monetizar → Configuração de monetização), informe `projects/<projeto>/topics/play-rtdn` e
   clique em **Enviar notificação de teste** (aparece no log da função como "notificação de
   teste").

### 5.4 AdMob

A conta já existe (`pub-2201002106451470`), e o `app-ads.txt` do site já tem a linha dela.

1. **Apps → Adicionar app → Android**, "O app está publicado?" **Não**, nome "BOSYN". Copie o ID
   do app (tem `~`).
2. **Blocos de anúncios:** um **Banner** ("Banner Home") e um **Premiado** ("Vídeo sessão PRO" —
   não escolha "Intersticial premiado"). Copie os dois IDs (têm `/`).
3. Confira: os 3 começam com `ca-app-pub-2201002106451470`; banner e premiado são diferentes.
   Cadastre `ADMOB_APP_ID`, `ADMOB_BANNER_ID` e `ADMOB_REWARD_ID` no GitHub e rode o botão 2 com
   **reais** uma vez, para conferência.
4. **Privacidade e mensagens:** crie a mensagem para a Europa (GDPR) com o link da política.
5. **Bloqueio de anúncios:** bloqueie as categorias sensíveis que não combinam com um app de saúde
   (por exemplo, namoro e apostas).
6. Nunca toque nos próprios anúncios reais nem peça para alguém tocar: o AdMob bloqueia a conta.
   Cadastre os celulares da equipe em **Configurações → Dispositivos de teste**.

Depois da aprovação na Play: vincule o app à loja no AdMob (Configurações do app → Detalhes da
app store) e clique em **Verificar atualizações** em Apps → app-ads.txt.

## 6. Site do desenvolvedor (políticas)

As duas páginas saem dos mesmos arquivos que o app mostra:

```bash
dart tool/legal_html.dart --publicar   # recusa enquanto houver [PREENCHER]
```

O resultado (`build/site/politica-bosyn.html` e `build/site/exclusao-de-conta-bosyn.html`) vai
para o repositório do site, `AlexFigueiras/alexfigueiras.github.io`, junto com um cartão do
BOSYN no `index.html` (sem apagar os jogos). O `app-ads.txt` desse site já vale para o BOSYN.
Na Play Console, o campo **Site** da loja deve ser `https://alexfigueiras.github.io`.

## 7. Prazos e mudanças no radar

- **Brasil, desde 30/09/2026:** apps instalados por fora da Play em aparelhos certificados
  precisam de desenvolvedor verificado. Distribua testes pela própria Play (teste interno ou
  fechado), não por APK solto.
- **Fevereiro de 2027:** novos limites de memória e de otimização de código para apps grandes.
- **Abril de 2027:** apps com login vão precisar restaurar o login num aparelho novo (Restore
  Credentials API).
- **Fim de 2026:** o Supabase desliga as chaves legadas `anon`/`service_role`. O app já usa
  `publishableKey`; o botão 2 avisa se ainda for a legada.

## 8. O que fica verificado automaticamente

- `dart tool/verify_rules.dart` (pre-commit e CI) bloqueia: `.env` empacotado como asset; pacote
  `com.example`; release assinado com a chave debug; `allowBackup` ligado; manifesto sem o ID do
  AdMob (o SDK fecha o app ao abrir).
- Job `release-check`: APK de release com R8 e 16 KB (`zipalign -P 16` e
  `tool/check_elf_alignment.dart`) e o ensaio do AAB com chave descartável
  (`tool/play/preparar_chave.sh` e `tool/play/conferir_aab.sh`).
- Job `edge-functions`: tipos, lint, formato e testes das regras da assinatura
  (`supabase/functions/_shared/*_test.ts`).

## Fontes

- Target API: https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB: https://developer.android.com/guide/practices/page-sizes
- Exclusão de conta: https://support.google.com/googleplay/android-developer/answer/13327111
- Declaração de apps de saúde: https://support.google.com/googleplay/android-developer/answer/14738291
- Conteúdo e serviços de saúde: https://support.google.com/googleplay/android-developer/answer/16679511
- Tipo de conta (organização): https://support.google.com/googleplay/android-developer/answer/10788890
- Pagamentos: https://support.google.com/googleplay/android-developer/answer/9858738
- Assinaturas (política): https://support.google.com/googleplay/android-developer/answer/140504
- Play Billing Library e prazos: https://developer.android.com/google/play/billing/deprecation-faq
- Verificar compras no servidor: https://developer.android.com/google/play/billing/security
- subscriptionsv2: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
- RTDN: https://developer.android.com/google/play/billing/getting-ready#configure-rtdn
- AdMob — consentimento (UMP): https://developers.google.com/admob/android/privacy
- AdMob — app-ads.txt: https://support.google.com/admob/answer/9363762
- Teste fechado (contas pessoais novas): https://support.google.com/googleplay/android-developer/answer/14151465
- Segurança dos dados: https://support.google.com/googleplay/android-developer/answer/10787469
- Assinatura de apps: https://developer.android.com/studio/publish/app-signing
- Verificação de desenvolvedor: https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html
- Chaves do Supabase: https://supabase.com/docs/guides/api/api-keys
