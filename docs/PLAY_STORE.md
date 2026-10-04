# Publicação na Google Play — BOSYN

> Levantamento de requisitos em 2026-10-04, com fontes oficiais ao final. Estado do código em
> `docs/STATUS.md`; o porquê das mudanças em `docs/DECISIONS.md`; segurança em
> `docs/SECURITY_REVIEW.md`.

## Veredito

**Ainda não está pronto para enviar.** Os requisitos que dependem de código foram resolvidos
nesta rodada (tabela 1). O que falta depende de você: contas, chaves, consoles e revisão
jurídica (seção 2). Três itens podem impedir a publicação mesmo com o app perfeito:

1. **Tipo de conta de desenvolvedor.** A Play classifica "cuidados auditivos" e
   "reabilitação" como apps **médicos**, e apps médicos exigem **conta de organização**
   (com D-U-N-S). Conta pessoal provavelmente não serve.
2. **Enquadramento regulatório.** O app promete "reabilitação" e faz um teste de limiar
   auditivo. Ao mesmo tempo, a Play exige o aviso "não é dispositivo médico" para quem não tem
   registro. As duas coisas não convivem bem: defina o posicionamento com um especialista
   (ANVISA, RDC 657/2022 — software como dispositivo médico) antes de escrever a ficha da loja.
3. **Chaves vazadas.** O repositório é público e o histórico do git contém o `.env` antigo
   com chaves reais. Rotacione as chaves antes de qualquer build de produção.

## 1. Requisitos técnicos — estado no código

| Requisito da Play | Estado | Onde |
|---|---|---|
| Target API 36 (obrigatório para apps novos e atualizações desde 31/08/2026) | ✅ `targetSdk = 36` fixado, `compileSdk ≥ 36` | `android/app/build.gradle.kts` |
| Páginas de 16 KB (apps com código nativo) | ✅ NDK r28 + flags de linker; o CI comprova a cada push | `cpp/CMakeLists.txt`, job `release-check` |
| AAB assinado com chave de upload (nunca chave debug) | ✅ lê `android/key.properties`; o build do AAB falha sem ele | `android/app/build.gradle.kts` |
| Pacote definitivo (nada de `com.example`) | ✅ `com.bosyn.app` — **confirme antes do 1º upload; depois não muda** | idem |
| Nome do app no aparelho | ✅ "BOSYN" | `AndroidManifest.xml` |
| Só as permissões necessárias | ✅ microfone e Bluetooth removidos (não eram usados) | idem |
| Exclusão de conta dentro do app | ✅ Conta e Privacidade → Excluir (pede a senha) | `lib/ui/screens/account_screen.dart` |
| Política de privacidade dentro do app | ✅ mesmo arquivo publicado na web | `docs/legal/politica-de-privacidade.md` |
| Aviso de saúde | ✅ onboarding, cadastro e tela de conta | `lib/core/legal_documents.dart` |
| Consentimento para dado de saúde (divulgação destacada + LGPD) | ✅ checkbox não pré-marcado no cadastro, com versão da política | `lib/ui/screens/auth_screen.dart` |
| Nenhum segredo dentro do APK | ✅ chave do Google TTS saiu do app | `supabase/functions/tts/` |
| Pagamentos pela política da Play | ✅ checkout falso removido; PRO "em breve" | `lib/ui/screens/home_screen.dart` |
| Conteúdo placeholder ("Palavra1") fora do treino | ✅ | `lib/core/gamification_controller.dart` |
| Ícone próprio do app | ⬜ ainda é o ícone padrão do Flutter | `android/app/src/main/res/mipmap-*` |
| Teste em tablet/dobrável (Android 16 ignora travas de orientação em telas ≥ 600 dp) | ⬜ | — |

## 2. O que você precisa fazer, em ordem

1. **Rotacionar as chaves expostas** (passo a passo em `docs/SECURITY_REVIEW.md`, item C1):
   apague a chave antiga do Google TTS e crie outra restrita à API Text-to-Speech; no Supabase,
   crie as chaves novas (`sb_publishable_…`/`sb_secret_…`) e desligue as legadas.
2. **Aplicar `supabase_migration_003_security.sql`** no SQL Editor do Supabase.
3. **Publicar as Edge Functions** (pasta `supabase/functions/`), com a Supabase CLI:
   ```bash
   supabase functions deploy tts --project-ref <ref-do-projeto>
   supabase functions deploy delete-account --project-ref <ref-do-projeto>
   supabase secrets set GOOGLE_TTS_API_KEY=<chave-nova> --project-ref <ref-do-projeto>
   ```
   No Google Cloud, limite a cota diária da API Text-to-Speech e crie um alerta de orçamento.
   Sem a função `tts` publicada, os treinos não têm áudio.
4. **Ajustar o Auth do Supabase:** confirmação de e-mail ligada, senha mínima de 8
   caracteres, SMTP próprio (o e-mail embutido envia só 2 mensagens por hora para o projeto
   todo) e, no plano Pro, proteção contra senhas vazadas. Em **Authentication → Email
   Templates → Reset Password**, inclua o código no corpo, por exemplo
   `<p>Seu código para criar uma nova senha: <strong>{{ .Token }}</strong></p>`. A tela
   "Esqueci minha senha" do app pede esse código de 6 números; sem ele no e-mail, a
   recuperação não funciona (o app não tem deep link para o link padrão).
5. **Preencher os `[PREENCHER]`** de `docs/legal/politica-de-privacidade.md` e
   `docs/legal/exclusao-de-conta.md` (controlador, CPF/CNPJ, e-mail, encarregado, região do
   Supabase), revisar com um advogado e publicar as duas páginas numa URL pública. Exemplo:
   GitHub Pages servindo a pasta `/docs`, ou o site do produto. Coloque a URL da página de
   exclusão no item 10 da política.
6. **Criar a chave de upload e gerar o AAB** (seção 3).
7. **Trocar o ícone** e preparar a ficha da loja: ícone 512×512, gráfico de destaque
   1024×500 e capturas de tela.
8. **Conta de desenvolvedor:** confirme se a sua conta é de organização. Se for pessoal e
   tiver sido criada depois de 13/11/2023, a Play exige um teste fechado com **12 testadores
   por 14 dias seguidos** antes de liberar a produção.
9. **Revisão regulatória e jurídica** (ver Veredito, item 2) antes de escrever a descrição da
   loja.

## 3. Build do AAB

Crie a chave de upload uma única vez e guarde-a fora do repositório, com backup:

```bash
keytool -genkey -v -keystore ~/bosyn-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crie `android/key.properties` (já está no `.gitignore`):

```properties
storePassword=<senha>
keyPassword=<senha>
keyAlias=upload
storeFile=C:/Users/<você>/bosyn-upload.jks
```

Gere o AAB, sempre ofuscado:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
```

- Guarde a pasta `build/debug-info` de cada versão: sem ela não dá para ler os stack traces
  ofuscados (`flutter symbolize`).
- Suba `build/app/outputs/bundle/release/app-release.aab` na Play Console, com o Play App
  Signing ativado. A Play guarda a chave de assinatura e você mantém só a de upload.
- Antes de enviar, rode `dart tool/verify_rules.dart`. No Play Console, abra **App bundle
  explorer** e confirme a compatibilidade com 16 KB.
- A cada versão, aumente o número depois do `+` em `version:` no `pubspec.yaml`.

## 4. Formulários do Play Console ("Conteúdo do app")

| Formulário | Resposta |
|---|---|
| Política de privacidade | URL pública de `docs/legal/politica-de-privacidade.md` |
| Acesso ao app | O app exige login: crie uma conta só para a revisão (e-mail confirmado) e informe login e senha. Os níveis PRO aparecem bloqueados ("em breve") |
| Anúncios | Não contém anúncios |
| Classificação de conteúdo | Preencha o questionário (app de saúde, sem conteúdo sensível) |
| Público-alvo | 18 anos ou mais. Faixas abaixo de 13 anos ativam a política de Famílias |
| Apps de saúde | Declare as categorias. "Cuidados auditivos" e "reabilitação" ficam no grupo médico, que exige conta de organização (Veredito, item 1) |
| Recursos financeiros | Nenhum. O formulário é obrigatório para todo app |
| Exclusão de conta | URL pública de `docs/legal/exclusao-de-conta.md` |
| Segurança dos dados | Tabela abaixo |

**Segurança dos dados**, com base no que o código coleta hoje:

| Categoria (Play) | Coletado | Compartilhado | Finalidade | Obrigatório |
|---|---|---|---|---|
| Informações pessoais → Endereço de e-mail | Sim | Não | Gerenciamento da conta | Sim |
| Informações pessoais → IDs do usuário | Sim (id da conta) | Não | Gerenciamento da conta, funcionalidade | Sim |
| Saúde e condicionamento físico → Informações de saúde | Sim (limiares do teste auditivo, resultados do treino) | Não | Funcionalidade do app (personalizar o treino) | Sim |
| Atividade no app → Interações no app | Sim (respostas por estímulo, tempo de reação, progresso) | Não | Funcionalidade do app | Sim |
| Áudio, localização, contatos, fotos, IDs de publicidade | Não coletados | — | — | — |

- Dados criptografados em trânsito: **sim**.
- O usuário pode pedir a exclusão: **sim** (no app e pela página web).
- Fornecedores que atuam em seu nome (Supabase como hospedagem) não contam como
  "compartilhamento" na Play. O Google TTS recebe só a palavra a ser falada, nenhum dado do
  usuário.
- Se o app mudar (por exemplo, com compras ou analytics), atualize o formulário antes de
  publicar.

**Descrição da loja.** A Play exige que a descrição:

- diga que o app "não é um dispositivo médico e não diagnostica, trata, cura nem previne
  doenças";
- recomende procurar um profissional;
- avise que é preciso usar **fones de ouvido**;
- não faça promessas de resultado clínico.

## 5. Monetização (BOSYN PRO)

Vender recurso digital dentro do app (liberar níveis, assinatura) **exige o Google Play
Billing**. Stripe sozinho para isso viola a política e leva à reprovação ou remoção do app. No
Brasil, apps que não são jogos podem aderir ao *user choice billing*: o Play Billing aparece
lado a lado com outro meio de pagamento.

O caminho recomendado:

- Pacote `in_app_purchase` no app. É uma dependência nova e precisa da sua aprovação
  (AGENTS.md).
- Validação da compra numa Edge Function, com notificações em tempo real da Play (RTDN).
- O plano gravado em `profiles.subscription_status` pelo servidor (`service_role`). O banco já
  ignora qualquer mudança de plano feita pelo cliente (migration 003).

O app usa a Play Billing Library 8 ou mais recente desde 31/08/2026.

## 6. Prazos e mudanças no radar

- **Brasil, desde 30/09/2026:** apps instalados por fora da Play em aparelhos certificados
  precisam de desenvolvedor verificado. Um APK de teste mandado direto a testadores
  brasileiros pode ser bloqueado. Distribua testes pela própria Play (teste interno ou
  fechado).
- **Fevereiro de 2027:** novos limites de memória e de otimização de código para apps
  grandes.
- **Abril de 2027:** apps com login vão precisar restaurar o login num aparelho novo (Restore
  Credentials API).
- **Fim de 2026:** o Supabase desliga as chaves legadas `anon`/`service_role`. O app já usa
  `publishableKey`; falta só gerar a chave nova (seção 2, item 1).

## 7. O que fica verificado automaticamente

- `dart tool/verify_rules.dart`, no pre-commit e no CI, bloqueia quatro regressões:
  - `.env` empacotado como asset;
  - pacote `com.example`;
  - release assinado com a chave debug;
  - `allowBackup` ligado.
- O job de CI `release-check` gera um APK de release (R8 e ofuscação ligados) e falha se
  alguma biblioteca nativa 64-bit não estiver alinhada a 16 KB (`zipalign -P 16` e
  `tool/check_elf_alignment.dart`).

## Fontes

- Target API: https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB: https://developer.android.com/guide/practices/page-sizes
- Exclusão de conta: https://support.google.com/googleplay/android-developer/answer/13327111
- Declaração de apps de saúde: https://support.google.com/googleplay/android-developer/answer/14738291
- Conteúdo e serviços de saúde: https://support.google.com/googleplay/android-developer/answer/16679511
- Tipo de conta (organização): https://support.google.com/googleplay/android-developer/answer/10788890
- Pagamentos: https://support.google.com/googleplay/android-developer/answer/9858738
- User choice billing: https://support.google.com/googleplay/android-developer/answer/13821247
- Teste fechado (contas pessoais novas): https://support.google.com/googleplay/android-developer/answer/14151465
- Segurança dos dados: https://support.google.com/googleplay/android-developer/answer/10787469
- Assinatura de apps: https://developer.android.com/studio/publish/app-signing
- Verificação de desenvolvedor: https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html
- Chaves do Supabase: https://supabase.com/docs/guides/api/api-keys
