# STATUS — o que está pronto, parcial ou a fazer
> LEIA ISTO PRIMEIRO (antes de propor/implementar qualquer feature).
> Estado por feature. Histórico do *porquê* fica em `docs/DECISIONS.md`; visão do produto, em
> `#PROJECT_BRAIN.md` e `docs/MASTER_PLAN.md`; skills/contexto locais, em `.agent/skills/`.
> Legenda: ✅ pronto/funcionando · 🟡 parcial ou não auditado a fundo · ⬜ a fazer · 🚫 fora de escopo
> Última auditoria: 2026-10-04 (prontidão para Google Play + revisão de segurança — ver
> `docs/PLAY_STORE.md` e `docs/SECURITY_REVIEW.md`); auditoria inicial brownfield em 2026-07-18
>
> **Nota de auditoria:** as linhas abaixo confirmam apenas que o arquivo/feature **existe no
> código**. Comportamento clínico, correção de DSP e cobertura de teste não foram verificados
> linha a linha neste bootstrap — por isso a maioria está 🟡, não ✅ (regra: "STATUS impreciso é
> pior que ausente").

## Fundação Dev OS (este bootstrap)
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Fundação Dev OS (governança adaptada) | ✅ | `AGENTS.md`, `MASTER-PLAN.md`, `tool/`, `.githooks/`, `docs/` | Ver `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md` para o que foi reduzido/adiado |

## Publicação Google Play
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Configuração de release Android (pacote, assinatura, targetSdk 36, 16 KB, backup, rede, permissões mínimas) | 🟡 | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/`, `cpp/CMakeLists.txt` | Código pronto; build Android não verificado localmente (sem Android SDK) — prova fica no job `release-check` do CI. Falta keystore de upload (ação humana) |
| Checklist da Play (formulários, Data safety, contas, prazos) | 🟡 | `docs/PLAY_STORE.md` | Bloqueadores humanos: rotação de chaves, deploy das Edge Functions, migration 003, `[PREENCHER]` nos textos legais, conta de organização, revisão regulatória |
| Trava automática de regressão de release | ✅ | `tool/checks/check_release_config.dart`, `tool/check_elf_alignment.dart`, job `release-check` | Testada nos dois sentidos (passa no estado atual, falha contra a config antiga) |

## Plano "treino eficaz" (branch `claude/treino-eficaz`)
Plano aprovado em 2026-10-04: 14 etapas (0–13), uma por vez; cada uma só fecha com CI verde +
checklist de escuta no celular (APK de profile). Análise e porquês em `docs/DECISIONS.md`.
| Etapa | Estado | Notas |
|---|---|---|
| 0 — Base verde (analyze limpo, job `native-tests`, APK de profile no CI) | ✅ | CI verde (run 37238438644); checklist ok do usuário |
| 1 — Limpeza e promessas | ✅ | CI verde; checklist ok do usuário |
| 2 — Áudio que sai errado (TTS 48 kHz, ruído que não desliga, Repetir) | 🟡 | CI verde (run 37240201716). Checklist no celular adiado pelo usuário (fazer junto com a Etapa 3). **Ação humana:** publicar a Edge Function `tts` atualizada |
| 3 — Motor C++ consertado (EQ multibanda, bypass de medição, limitador) | 🟡 | CI verde (run 37241421987, inclui TSan). Checklist no celular adiado pelo usuário |
| 4 — Teste auditivo confiável | 🟡 | CI verde (run 37243740170). Checklist no celular adiado pelo usuário. Home e onboarding abrem o teste novo (commit 66031f6, auditoria de UX) |
| 5 — Banco de estímulos que obriga a ouvir | 🟡 | CI verde (run 37244933547). Checklist no celular adiado pelo usuário |
| 6 — Feedback e fim de sessão | 🟡 | CI verde (run 37247213640). Checklist no celular adiado pelo usuário |
| 7 — Dificuldade real + Coquetel com ruído de fala | 🟡 | Código pronto; aguardando CI e checklist |
| 8 — Medida de progresso (dígitos no ruído) | ⬜ | |
| 9 — Espacial redesenhado | ⬜ | |
| 10 — Gamificação alinhada ao treino | ⬜ | |
| 11 — Acessibilidade e linguagem | ⬜ | |
| 12 — Documentação final + PR | ⬜ | |
| 13 — Rebaixamento de frequência (opcional) | ⬜ | Só com validação de fonoaudiólogo |

## Produto — telas e fluxos
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Autenticação | 🟡 | `lib/ui/screens/auth_screen.dart`, `auth_widgets.dart`, `password_reset_screen.dart`, `lib/core/auth_messages.dart`, `lib/ui/screens/session_gate.dart`, `lib/services/supabase_service.dart` | Raiz reage à sessão (login/logout/exclusão). Cadastro com consentimento LGPD para dado de saúde. Etapa A da auditoria de UX (2026-10-04): erros em pt-BR junto do campo, campos com nome acessível e autofill, mostrar senha, reenvio da confirmação de e-mail, "Esqueci minha senha" por código de 6 dígitos — verificado em `test/auth_*_test.dart` e de ponta a ponta com Supabase simulado. **Recuperação depende de `{{ .Token }}` no modelo de e-mail "Reset Password"** (ação humana, `docs/PLAY_STORE.md` item 4). RLS canônica em `supabase_migration_003_security.sql` (**não aplicada** — ação humana) |
| Conta e privacidade (sair, excluir conta, política no app) | 🟡 | `lib/ui/screens/account_screen.dart`, `lib/services/account_service.dart`, `lib/ui/screens/legal_document_screen.dart`, `docs/legal/`, `supabase/functions/delete-account/` | Código pronto; exclusão depende de publicar a Edge Function e aplicar a migration 003. Textos legais com `[PREENCHER]` |
| Configuração de build e fail-fast no boot | ✅ | `lib/core/app_config.dart`, `lib/ui/screens/startup_error_screen.dart`, `lib/main.dart` | `--dart-define-from-file=.env`; recusa chave que não seja publishable/anon. Coberto por `test/app_config_test.dart` |
| Onboarding | 🟡 | `lib/ui/screens/onboarding_screen.dart` | Abre com o aviso de saúde; sem promessa de "remapear" a audição; "Pular teste" pula de fato (Etapa 1). Etapa B da auditoria de UX: linguagem comum, texto ≥ 16 px, botões com nome acessível ("Próximo", "Fazer o teste depois", "Começar o teste"), check de som que pergunta "Você ouviu o som?" e orienta se não ouviu, aviso quando o teste é adiado. Coberto por `test/onboarding_screen_test.dart` (inclui 360×640 com fonte 200%). Checagem automática de ambiente silencioso e tom de treino ficam com a Etapa 4 do plano |
| Calibração de latência | 🟡 | `lib/ui/screens/calibration_screen.dart` | Travava no primeiro toque (símbolo nativo `get_current_timestamp_ns` inexistente) — corrigido na Etapa 2. Bip a -20 dBFS com rampa |
| Home / dashboard de treino | 🟡 | `lib/ui/screens/home_screen.dart`, `lib/ui/screens/home_widgets.dart` | Achado E2 da auditoria de UX: cartão "Comece pelo teste de audição" para quem não tem audiograma, gráfico vazio com texto (sem ponto falso em 0%), "Refazer teste de audição" para quem já tem, Home rolável (360×640 e fonte 200% sem corte). Coberto por `test/home_widgets_test.dart`. Indicadores (XP, streak, gráfico) seguem para a Etapa 10 do plano. Existe **duplicidade estrutural**: há uma segunda árvore de telas em `lib/screens/` paralela a `lib/ui/screens/` — não resolvida neste bootstrap (decisão que toca `lib/`, fora de escopo, ver `docs/ARCHITECTURE.md`) |
| Teste auditivo (limiar tonal) | 🟡 | `lib/screens/threshold_test_screen.dart`, `lib/screens/hearing_test/`, `lib/training/threshold_procedure.dart`, `hearing_test_session.dart`, `hearing_summary.dart`, `lib/services/audio_output_service.dart` | Etapa 4: Hughson-Westlake modificado com tentativas silenciosas (2 de verificação antes de aceitar), "sem resposta" no máximo, 250 Hz–8 kHz com 3/6 k e reteste de 1 k, tom pulsado sem processamento, fone e volume fixo checados, resultado rolável com audiograma clínico, categoria OMS aproximada e próximo passo. **Triagem relativa, não dB HL clínico.** Precisão em simulação: ~80% a ±5 dB, ~100% a ±10 dB |
| Discriminação fonêmica ("Palavras parecidas") | 🟡 | `lib/screens/phonemic_discrimination_screen.dart`, `lib/training/stimulus_bank.dart`, `lib/training/item_selector.dart` | Etapa 5: 49 pares de palavras reais (s×ch, s×f, t×p, t×k, plural, + aquecimento grave); qualquer palavra do par toca; 3 vozes; seleção por perda e erros recentes; guarda de audibilidade. Feedback e resumo vêm na Etapa 6; escada definitiva na Etapa 7 |
| Atenção espacial | 🟡 | `lib/screens/spatial_attention_screen.dart` | Existe; monaural e sem adaptação — redesenho na Etapa 9 |
| Fala no ruído ("Conversa no barulho") | 🟡 | `lib/screens/speech_in_noise_screen.dart`, `lib/audio_engine/masker_bank.dart`, `lib/training/adaptive_staircase.dart` | Etapa 7: ruído contínuo com espectro de fala ou burburinho de 6 vozes (SNR exato, mesmo RMS da fala), 4 opções {sala, fala, salas, falas}, frase "Diga ___ agora", escada 3-acertos/1-erro retomada entre sessões, sessão de ~10 min com "Terminar" |
| Gamificação (XP / Streak) | 🟡 | `lib/core/gamification_controller.dart` | Energia Neural removida na Etapa 6 (punia o erro que a escada produz de propósito). XP/nível/streak ainda os antigos — reescritos na Etapa 10 |
| Relatório clínico / missão | 🚫 | — | Removido na Etapa 1 (código órfão; o PDF "clínico" tinha números inventados). Resumo de sessão honesto vem na Etapa 6 |
| Painel técnico + QA de áudio (oculto, long-press no topo da Home) | 🟡 | `lib/screens/widgets/technical_dashboard.dart`, `qa_audio_panel.dart` | Carga do DSP, xruns, acionamentos do limitador; em debug/profile: tons por orelha e palavra com/sem EQ (Etapa 3) |
| Motor de áudio nativo (C++/Oboe via FFI) | 🟡 | `cpp/audio_graph.*`, `cpp/eq_bank.h`, `cpp/buffer_source.h`, `cpp/handoff.h`, `cpp/safety_limiter.h`, `cpp/oboe_engine.*`, `cpp/native_bridge.cpp`, `lib/audio_engine/` | Reescrito na Etapa 3: EQ de 8 bandas por orelha (biquads), ruído mixado depois do EQ, bypass para tons de medição, limitador -1 dBFS, troca de buffer sem lock. Testado no host (`cpp/tests/`, ASan/UBSan + TSan); no celular, só pelo checklist |
| Telemetria / persistência Supabase | 🟡 | `lib/services/supabase_service.dart`, `lib/services/event_buffer.dart`, `lib/models/rehab_session.dart` | Arquivo offline pendente agora tem dono (não sobe na conta de outro usuário) e é apagado no logout/exclusão |
| TTS (text-to-speech) | 🟡 | `lib/services/tts_service.dart`, `lib/audio_engine/wav_decoder.dart`, `supabase/functions/tts/` | Via Edge Function autenticada. Pede 48 kHz (Etapa 2); o app lê a taxa real do WAV e reamostra, então funciona antes e depois do deploy. Cache persistente (pasta de suporte), chave `v2`. **Sem a função publicada não há áudio nos treinos** |
| Gatekeeper / paywall | 🟡 | `lib/services/gatekeeper_service.dart`, `lib/ui/screens/home_screen.dart` | Só lê o plano; plano escrito apenas pelo servidor (migration 003). Checkout falso e `flutter_stripe` removidos; PRO "em breve" até integrar Google Play Billing (decisão pendente, ver `docs/PLAY_STORE.md` §5). Achado F1 da auditoria de UX: cadeado e "Plano PRO, em breve" vêm do plano real (antes eram fixos no código, inclusive para quem tinha PRO); treinos com nome e descrição em linguagem comum; aviso do PRO em pt-BR, honesto ("ainda não está à venda", "nada será cobrado sem confirmação na loja"), com altura que mostra o botão em telas pequenas. Quando houver venda, a folha precisa de preço, renovação e cancelamento |
| Modelos de domínio | 🟡 | `lib/models/audiogram.dart`, `rehab_session.dart` | `phonemic_pair.dart` (órfão, assets inexistentes) removido na Etapa 1 |

## Débitos e riscos conhecidos (não corrigidos neste bootstrap, por estarem fora do escopo "não tocar em lib/código")
| Item | Estado | Notas |
|---|---|---|
| `.env` commitado com segredos reais | ⬜ | **Repositório é público** (verificado em 2026-10-04). O app não usa mais a chave do Google TTS e o `.env` não é mais empacotado, mas as chaves antigas seguem válidas no histórico. **Rotação pendente — ação humana urgente** (passo a passo em `docs/SECURITY_REVIEW.md`, C1) |
| Branches remotos `claude/*` não mesclados | ⬜ | `origin/claude/app-theme-layout-bugs-NShoJ` (25 commits à frente), `unify-friendly-ui` (22), `determined-clarke-GSF85` (12, inclui `supabase/schema.sql` com `profiles` e trigger de cadastro). São de jun/2026, anteriores ao `main` atual; mesclá-los vai conflitar com home/auth/pubspec/schema. Decidir: mesclar, aproveitar partes ou arquivar |
| Duplicidade `lib/screens/` vs `lib/ui/screens/` | ⬜ | Sintoma de refatoração incompleta; não resolvida — decisão que toca `lib/`, fora do escopo deste bootstrap |
| Código morto alcançável só por si mesmo | ✅ | Removido na Etapa 1 do plano de treino eficaz: `training_dashboard`, `mission_report_screen`, `pdf_service` (+ deps `pdf`/`printing`), `spatial_controller`, `performance_dashboard`, `rehab_trends_chart`, `phonemic_pair` |
| Logger estruturado (substituir `print`/`debugPrint`) | 🟡 | Todos os `print` viraram `debugPrint`, desligado em release (`lib/main.dart`). Logger estruturado de verdade segue como follow-up (módulo 05) |
| Cobertura de testes automatizados | 🟡 | Suíte inicial: `test/app_config_test.dart`, `legal_documents_test.dart`, `gamification_controller_test.dart`, `check_elf_alignment_test.dart`, `widget_test.dart`. Telas de treino, engine e serviços seguem sem teste |
| Arquivos soltos na raiz (`analysis.txt`, `build_log.txt`, `debug_env.log`, `write_test.txt`) | ⬜ | Lixo de debug versionado; não removido neste bootstrap (decisão do usuário, não higiene automática) |
| Plataforma iOS ausente | 🚫 | Só `android/`, `web/`, `windows/` existem; fora de escopo deste bootstrap (decisão de stack/plataforma, não de governança) |
| `skills-library/CATALOG.md` | 🟡 | Catálogo genérico de ~1.262 skills de mercado, **não curado para este projeto** (confirmado por leitura: contém skills de Angular, Godot, Elixir etc., sem relação com Flutter/audiologia). Distinto de `.agent/skills/`, que É específico deste projeto. Ver `docs/DECISIONS.md`. |
| `flutter analyze` limpo | ✅ | Resolvido na Etapa 0 do plano de treino eficaz (2026-10-04): 0 issues. `ffi` e `shared_preferences` declarados no pubspec com aprovação do usuário (já eram usados via dependência transitiva) |
| `dart format` — 29 dos 33 arquivos `.dart` de `lib/` não estão formatados no padrão `dart format` | ⬜ | Descoberto ao tentar endurecer o step "Verify formatting" do CI. Reformatar é whitespace-only, mas toca todo `lib/` — mantido como `continue-on-error: true` no CI por decisão explícita (ver `.github/workflows/ci.yml` e `docs/DECISIONS.md`), não corrigido neste bootstrap. |
| `flutter test` não executa localmente nesta máquina | 🟡 | Falta toolchain de compilador C (Visual Studio Build Tools/MSVC) para o build de native assets do pacote `win32` (dependência transitiva de `device_info_plus`); desligar native assets não resolve (`win32` os exige). Não deve reproduzir no CI (`ubuntu-latest` tem `gcc`). `dart tool/verify_rules.dart` roda normalmente (reverificado em 2026-10-04). Esta máquina também não tem Android SDK: build Android só no CI |

## Regras de uso (deste STATUS)
- **Brownfield:** a auditoria acima confirma existência no código, não corretude. `✅` só para o
  confirmado a fundo; na dúvida, `🟡`/`⬜`.
- **Granularidade:** uma linha por feature de usuário ou fluxo de negócio, não por arquivo.
- **Papéis:** STATUS = estado · DECISIONS = porquê · `#PROJECT_BRAIN.md`/`docs/MASTER_PLAN.md` =
  produto · `.agent/skills/*/SKILL.md` = como. Não fundir estes papéis.
