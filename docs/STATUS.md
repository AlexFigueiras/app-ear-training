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
| 0 — Base verde (analyze limpo, job `native-tests`, APK de profile no CI) | 🟡 | Teste da política (pumpAndSettle estourava esperando o asset em tempo simulado) corrigido; aguardando CI verde |
| 1 — Limpeza e promessas | 🟡 | Código pronto; aguardando CI e checklist |
| 2 — Áudio que sai errado (TTS 48 kHz, ruído que não desliga, Repetir) | ⬜ | |
| 3 — Motor C++ consertado (EQ multibanda, bypass de medição, limitador) | ⬜ | |
| 4 — Teste auditivo confiável | ⬜ | |
| 5 — Banco de estímulos que obriga a ouvir | ⬜ | |
| 6 — Feedback e fim de sessão | ⬜ | |
| 7 — Dificuldade real + Coquetel com ruído de fala | ⬜ | |
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
| Onboarding | 🟡 | `lib/ui/screens/onboarding_screen.dart` | Abre com o aviso de saúde; sem promessa de "remapear" a audição; "Pular teste" pula de fato (Etapa 1) |
| Calibração de áudio | 🟡 | `lib/ui/screens/calibration_screen.dart` | Existe; é âncora clínica de todos os níveis (`docs/MASTER_PLAN.md` §4.3) |
| Home / dashboard de treino | 🟡 | `lib/ui/screens/home_screen.dart` | Existe **duplicidade estrutural**: há uma segunda árvore de telas em `lib/screens/` paralela a `lib/ui/screens/` — não resolvida neste bootstrap (decisão que toca `lib/`, fora de escopo, ver `docs/ARCHITECTURE.md`) |
| Teste de limiar tonal (Threshold Test) | 🟡 | `lib/screens/threshold_test_screen.dart` | Existe |
| Discriminação fonêmica | 🟡 | `lib/screens/phonemic_discrimination_screen.dart`, `lib/core/phoneme_map.dart` | Existe |
| Atenção espacial | 🟡 | `lib/screens/spatial_attention_screen.dart` | Existe; monaural e sem adaptação — redesenho na Etapa 9 |
| Fala no ruído (Speech-in-Noise) | 🟡 | `lib/screens/speech_in_noise_screen.dart` | Existe |
| Gamificação (XP / Energia Neural / Streak) | 🟡 | `lib/core/gamification_controller.dart` | Existe |
| Relatório clínico / missão | 🚫 | — | Removido na Etapa 1 (código órfão; o PDF "clínico" tinha números inventados). Resumo de sessão honesto vem na Etapa 6 |
| Painel técnico (oculto, long-press no topo da Home) | 🟡 | `lib/screens/widgets/technical_dashboard.dart` | `performance_dashboard`/`rehab_trends_chart` (órfãos) removidos na Etapa 1. Vira painel de "QA de áudio" na Etapa 3 |
| Engine de áudio nativo (DSP/FFI) | 🟡 | `lib/audio_engine/audio_engine.dart`, `lib/audio_engine/native_engine.dart`, `cpp/` | Crítico (latência clínica); sem teste automatizado conhecido |
| Telemetria / persistência Supabase | 🟡 | `lib/services/supabase_service.dart`, `lib/services/event_buffer.dart`, `lib/models/rehab_session.dart` | Arquivo offline pendente agora tem dono (não sobe na conta de outro usuário) e é apagado no logout/exclusão |
| TTS (text-to-speech) | 🟡 | `lib/services/tts_service.dart`, `supabase/functions/tts/` | Via Edge Function autenticada; a chave do Google saiu do app. **Sem a função publicada não há áudio nos treinos** |
| Gatekeeper / paywall | 🟡 | `lib/services/gatekeeper_service.dart`, `lib/ui/screens/home_screen.dart` | Só lê o plano; plano escrito apenas pelo servidor (migration 003). Checkout falso e `flutter_stripe` removidos; PRO "em breve" até integrar Google Play Billing (decisão pendente, ver `docs/PLAY_STORE.md` §5) |
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
