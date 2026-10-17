# Diário da missão: BOSYN na Google Play

> Diário da skill "publicar na Play Store", adaptada para este app (Flutter, saúde, assinatura e
> anúncios). Numa conversa nova, continue da primeira missão sem ✓. Passo a passo e respostas:
> `docs/PLAY_STORE.md` · textos da loja: `docs/play-store/ficha-da-loja.md` · respostas com
> botão Copiar: https://claude.ai/artifact/KynF31YyaytfpXmA47wYD7 (fonte:
> `docs/play-store/folha-de-respostas.html`). Estado do código: `docs/STATUS.md`.

- Produto: BOSYN, treino auditivo (não é dispositivo médico). Público: 18 anos ou mais.
- Responsável: Alex (diretoralexfigueiras@gmail.com). Na loja: desenvolvedor BOSYN, contato@bosyn.com.br.
- Pacote: `com.bosyn.app` (nunca muda depois do primeiro envio). Nome na loja: "BOSYN: Treino Auditivo".
- Repositório: `AlexFigueiras/app-ear-training` (**público**: veja a Missão 4).
- Site do desenvolvedor: https://alexfigueiras.github.io (já tem o `app-ads.txt` da conta do AdMob).
- Política: https://alexfigueiras.github.io/politica-bosyn.html · Exclusão de conta:
  https://alexfigueiras.github.io/exclusao-de-conta-bosyn.html (as duas **a publicar**, Missão 6a).
- Play Console: conta de **organização** da BOSYN, já liberada: sem teste fechado obrigatório de 12
  testadores por 14 dias.
- AdMob (não são senhas): conta `pub-2201002106451470` · app `____` · banner `____` · premiado `____`.
- Assinaturas: `bosyn_pro_mensal` (plano base `mensal`) e `bosyn_pro_anual` (plano base `anual`).

## Como a skill foi adaptada

| Na skill (jogo HTML) | No BOSYN |
|---|---|
| Capacitor monta o Android a partir de `www/` | O app já é Flutter: build com `flutter build appbundle` |
| Bloco `ADS` em JavaScript (banner + vídeo) | `AdsService` (google_mobile_ads): banner só na Home, vídeo libera 1 sessão PRO |
| Sem assinatura | `BillingService` (in_app_purchase, Billing 8) + Edge Functions que conferem cada compra |
| Público 13+ | 18+, app de saúde: Data safety, apps de saúde e aviso "não é dispositivo médico" |
| Repositório Private com botão 1 | Repositório público: chave pelo botão 1 só se ficar Private; senão, no computador |
| Política com texto de jogo | Política LGPD com dado de saúde, AdMob e assinatura, gerada do mesmo arquivo do app |

## Missões

- [x] 0. Contas: Play Console de organização (BOSYN, liberada), GitHub `AlexFigueiras`, AdMob `pub-2201002106451470`.
- [x] 1. Ficha: nome, pacote, público 18+, contato público BOSYN.
- [x] 2. Monetização no app: assinatura PRO ou 1 sessão por vídeo; banner só na Home; nunca anúncio no teste ou no treino. Código pronto e CI verde. **Falta testar no celular** (Missão 9A).
- [ ] 3. Código no `main`: mesclar `claude/treino-eficaz` e `claude/gracious-hopper-qmnsfs`. Só então os botões "1" e "2" aparecem em Actions.
- [ ] 4. Chave de upload (botão 1 com o repositório Private, ou no computador) + segredos + 1º AAB **teste** verde.
- [ ] 5. AdMob: app BOSYN + 2 blocos + 3 segredos + 1 AAB **reais** de conferência.
- [ ] 5S. Servidor (novo no BOSYN): rotação de chaves; migrations 003 e 004; Edge Functions `tts`, `delete-account`, `play-subscription`, `play-rtdn`; secrets; conta de serviço da Play; RTDN.
- [ ] 6. Site e textos: 6a preencher `[PREENCHER]` e publicar política e exclusão de conta; 6b capturas de tela (ícone e recurso gráfico ✓); 6c textos ✓; 6d Folha de Respostas ✓; 6e mensagem da Europa no AdMob.
- [ ] 7. Play Console: criar o app e responder "Conteúdo do app".
- [ ] 8. Página da loja: textos, ícone, recurso gráfico e capturas.
- [ ] 9A. Teste interno: AAB **teste**, instalar pela Play, checklist das Etapas 2–11 no celular, criar as assinaturas, compra de teste com testador de licença, vídeo premiado e banner.
- [ ] 9B. Produção: AAB **reais** (versão nº ____), países, enviar para revisão (data: ____).
- [ ] 10. Depois da aprovação: vincular o app no AdMob, verificar o `app-ads.txt`, notificação de teste do RTDN, celulares da equipe como dispositivos de teste.

## Anotações

- 2026-10-17: skill aplicada. Pedido do Alex: assinatura **ou** anúncios, à escolha de quem usa;
  Google Play Billing no lugar do Stripe (a política de pagamentos da Play exige o Billing para
  assinatura digital vendida no app).
- Senha da chave de upload: 12+ caracteres, **sem acento nem ç** (o Java recusa).
- Resposta dada sobre "atrair crianças" no Público-alvo: ____
