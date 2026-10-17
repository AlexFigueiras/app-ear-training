# Revisão de segurança — BOSYN (2026-10-04)

> Escopo: app Flutter (Android), Edge Functions e schema do Supabase. Referências: OWASP MASVS
> v2.1, documentação do Supabase, Google Cloud e Android, e LGPD (dado de saúde é dado pessoal
> sensível, art. 5º, II). Publicação na loja: `docs/PLAY_STORE.md`.

**Legenda:**

- ✅ **corrigido no código:** já vale no próximo build.
- 🟡 **corrigido, falta ativar:** precisa de deploy ou de aplicar a migration.
- ⬜ **pendente:** depende de ação humana ou de decisão sua.

## Crítico

### C1. Chaves reais no histórico de um repositório público ⬜

O `.env` versionado até jul/2026 (5 commits) contém `SUPABASE_URL`, `SUPABASE_ANON_KEY` e
`GOOGLE_TTS_API_KEY` reais, e o repositório no GitHub é público. Tirar o arquivo do índice do
git não invalida nada.

Conferido no histórico: nenhuma chave `service_role` ou `sb_secret_` real foi commitada.

Faça nesta ordem:

1. **Google Cloud → Credenciais:**
   - Apague a chave antiga. Ela é usável por qualquer pessoa e cobra na sua conta.
   - Confira o faturamento e o uso da API Text-to-Speech desde mar/2026.
   - Crie uma chave nova, restrita à API Text-to-Speech, e guarde-a só nos secrets da Edge
     Function `tts`.
   - Configure uma cota diária e um alerta de orçamento.
2. **Supabase → Project Settings → API Keys:**
   - Crie a chave `sb_publishable_…` e use-a no `.env` (`SUPABASE_PUBLISHABLE_KEY`).
   - Desligue as chaves legadas (`anon`/`service_role`). Isso mata a anon vazada, e as
     legadas serão removidas pelo Supabase no fim de 2026 de qualquer jeito.
   - Antes, confirme que nada além deste app usa as legadas.
3. **GitHub:**
   - Atualize os secrets do CI: crie `SUPABASE_PUBLISHABLE_KEY` e apague `GOOGLE_TTS_API_KEY`,
     que não é mais usado.
   - Opcional: reescreva o histórico com
     `git filter-repo --sensitive-data-removal --invert-paths --path .env` e force-push. O
     repositório não tem forks, mas os hashes mudam para todo mundo. Rotacionar (passos 1 e 2)
     é o que resolve; reescrever o histórico é limpeza.
   - Atenção: o secret scanning do GitHub não detecta chaves JWT legadas do Supabase.

### C2. Qualquer usuário podia se dar o plano PRO de graça 🟡

O botão "Ativar acesso elite" simulava um checkout de 2 segundos e gravava
`subscription_status = 'pro'` a partir do próprio app. O cadastro também gravava o plano pelo
cliente. Como a política de RLS permite ao usuário editar o próprio perfil, bastava uma
chamada à API para virar PRO.

- **Correção no app:** o upgrade pelo cliente foi removido e o PRO aparece como "em breve".
- **Correção no banco:** um trigger força `free` em qualquer escrita de `anon`/`authenticated`
  (`supabase_migration_003_security.sql`).
- **Falta:** aplicar a migration.

### C3. Chave do Google TTS dentro do APK ✅ (app) / 🟡 (função)

O `.env` era empacotado como asset do Flutter (`flutter_dotenv`), então qualquer pessoa
extraía a chave do APK.

- Agora o app chama a Edge Function `tts` com o JWT do usuário, e a chave fica só nos secrets
  da função.
- A configuração do app entra por `--dart-define-from-file`, e só as variáveis lidas pelo
  código vão para o binário (URL e chave publishable).
- O `verify_rules` bloqueia a volta do `.env` como asset.
- **Falta:** publicar a função.

## Alto

| # | Achado | Estado | Correção |
|---|---|---|---|
| A1 | Sem exclusão de conta. A Play exige no app e na web, e a LGPD dá o direito de eliminação (art. 18) | 🟡 | Tela Conta e Privacidade pede a senha de novo (MASVS-AUTH-3). A Edge Function `delete-account` usa `auth.admin.deleteUser` só no servidor, com o id vindo do JWT. A migration 003 põe `ON DELETE CASCADE`. Falta publicar a função e aplicar a migration |
| A2 | Telemetria offline de um usuário subia na conta de outro: o arquivo pendente não tinha dono e era enviado com o `user_id` de quem estivesse logado | ✅ | O arquivo leva o dono e só sobe para ele. Logout e exclusão apagam a telemetria pendente do aparelho |
| A3 | Release assinado com chave debug e pacote `com.example` | ✅ | `key.properties` + bloqueio do build do AAB sem ele. Pacote `com.bosyn.app` |
| A4 | Backup ligado (padrão): sessão do Supabase e dado clínico pendente iam para o backup em nuvem e para a transferência entre aparelhos | ✅ | `allowBackup="false"` + `dataExtractionRules` excluindo tudo |
| A5 | Permissões perigosas sem uso (`RECORD_AUDIO`, `BLUETOOTH_*`) e uma tela que bloqueava o app sem elas | ✅ | Removidas, junto com a tela. A detecção de fone usa `AudioManager.getDevices()`, que não pede permissão |
| A6 | Chaves legadas do Supabase serão desligadas no fim de 2026: o app pararia de funcionar | ✅ (código) / ⬜ (chave) | `supabase_flutter` 2.18 com `publishableKey`; falta gerar a chave nova (C1) |

## Médio

| # | Achado | Estado | Correção |
|---|---|---|---|
| M1 | Dado clínico no logcat em release (limiares do teste, ganhos em dB) | ✅ | `debugPrint` desligado em release; todos os `print` viraram `debugPrint` |
| M2 | Configuração de rede implícita | ✅ | `network_security_config`: só HTTPS e só CAs do sistema. HTTP local liberado apenas no build debug |
| M3 | Sem registro de consentimento para dado de saúde (LGPD art. 11, I) | ✅ | Checkbox não pré-marcado no cadastro. A versão da política e a data vão para os metadados do usuário |
| M4 | Estado em memória (XP, sequência, SNR) passava de uma conta para outra no mesmo aparelho | ✅ | `GamificationController.resetForNewUser()` no logout e na exclusão |
| M5 | RLS fora do padrão: sem `TO authenticated`, `auth.uid()` sem `select`, papel `anon` com acesso, tabela `profiles` sem versionamento | 🟡 | Migration 003 recria as políticas no padrão recomendado e revoga o `anon` |
| M6 | App quebrava sem contexto quando a configuração faltava | ✅ | `AppConfig.validate()` no boot. Também recusa chave que não seja publishable/anon, ou seja, nunca uma chave privilegiada |
| M7 | SDKs sem uso aumentando a superfície de ataque (`flutter_stripe`, `permission_handler`, `flutter_dotenv`, `http`) | ✅ | Removidos. Nenhuma dependência nova foi adicionada |

## Recomendações ainda não aplicadas

Todas dependem de decisão sua ou de dependência nova.

- **Sessão em armazenamento cifrado.** O `supabase_flutter` guarda a sessão em
  SharedPreferences (área privada do app, sem cifra). Com o backup desligado, o risco fica
  restrito a aparelho com root. Para cifrar, implemente um `LocalStorage` com
  `flutter_secure_storage` (dependência nova, precisa de aprovação) e passe em
  `FlutterAuthClientOptions(localStorage: …)`.
- **Supabase Auth:**
  - confirmação de e-mail obrigatória;
  - senha mínima de 8 caracteres (o app já exige 8 no cadastro);
  - SMTP próprio;
  - CAPTCHA no cadastro;
  - proteção contra senhas vazadas (plano Pro);
  - MFA na conta do painel do Supabase.
- **Security Advisor do Supabase:** rode depois de aplicar a migration 003 e zere os alertas.
- **Abuso da função `tts`:** se acontecer, adicione limite por usuário (tabela de uso) ou Play
  Integrity. A cota no Google Cloud é o teto de custo.
- **"Esqueci minha senha":** o fluxo não existe. Exige deep link no app (PKCE já é o padrão do
  cliente).
- **Portabilidade (LGPD art. 18, V):** hoje o pedido é por e-mail, como diz a política. Uma
  exportação dentro do app é opcional.
- **`FLAG_SECURE` nas telas de audiograma e relatório:** opcional. Impede capturas de tela,
  inclusive as do próprio usuário.
- **Dependências:** 61 pacotes têm versões maiores incompatíveis com as restrições atuais
  (`flutter pub outdated`). O Dependabot já está configurado.

## O que foi e o que não foi verificado

- ✅ `flutter analyze`:
  - 0 erros (havia 2);
  - nenhum aviso novo nos arquivos alterados;
  - os infos e warnings restantes são pré-existentes, a maioria `withOpacity` deprecado.
- ✅ `dart tool/verify_rules.dart` passa. O novo `check-release-config` falha, como deve,
  contra a configuração antiga.
- ✅ A lógica do verificador ELF de 16 KB e o vínculo política↔versão foram executados em Dart
  VM.
- ✅ As Edge Functions passaram na checagem de sintaxe TypeScript. **Não foram executadas.**
- ⬜ **Build Android, R8 e alinhamento de 16 KB:** não rodaram nesta máquina, que não tem
  Android SDK. Ficam a cargo do job `release-check` do CI no próximo push.
- ⬜ **`flutter test`:** não roda nesta máquina (o pacote `win32` exige compilador C, débito
  já registrado em `docs/STATUS.md`). Os testes novos rodam no CI.
- ⬜ **Migration 003:** não foi executada contra um banco. Aplique primeiro num projeto de
  teste ou num branch do Supabase.
