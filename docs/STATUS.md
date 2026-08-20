# STATUS — o que está pronto, parcial ou a fazer
> LEIA ISTO PRIMEIRO (antes de propor/implementar qualquer feature).
> Estado por feature. Histórico do *porquê* fica em `docs/DECISIONS.md`; visão do produto, em
> `#PROJECT_BRAIN.md` e `docs/MASTER_PLAN.md`; skills/contexto locais, em `.agent/skills/`.
> Legenda: ✅ pronto/funcionando · 🟡 parcial ou não auditado a fundo · ⬜ a fazer · 🚫 fora de escopo
> Última auditoria: 2026-07-18 (brownfield — auditado a partir do código, backfillado)
>
> **Nota de auditoria:** as linhas abaixo confirmam apenas que o arquivo/feature **existe no
> código**. Comportamento clínico, correção de DSP e cobertura de teste não foram verificados
> linha a linha neste bootstrap — por isso a maioria está 🟡, não ✅ (regra: "STATUS impreciso é
> pior que ausente").

## Fundação Dev OS (este bootstrap)
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Fundação Dev OS (governança adaptada) | ✅ | `AGENTS.md`, `MASTER-PLAN.md`, `tool/`, `.githooks/`, `docs/` | Ver `bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md` para o que foi reduzido/adiado |

## Produto — telas e fluxos
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Autenticação | 🟡 | `lib/ui/screens/auth_screen.dart`, `lib/services/supabase_service.dart` | Existe; RLS/isolamento por `user_id` não auditado neste bootstrap |
| Onboarding | 🟡 | `lib/ui/screens/onboarding_screen.dart` | Existe |
| Calibração de áudio | 🟡 | `lib/ui/screens/calibration_screen.dart` | Existe; é âncora clínica de todos os níveis (`docs/MASTER_PLAN.md` §4.3) |
| Home / dashboard de treino | ✅ | `lib/ui/screens/home_screen.dart`, `lib/ui/screens/training_dashboard.dart`, `lib/ui/widgets/` | Modularizado em componentes dedicados em `lib/ui/widgets/`; arquivos dentro do limite de 500 linhas |
| Teste de limiar tonal (Threshold Test) | 🟡 | `lib/screens/threshold_test_screen.dart` | Existe |
| Discriminação fonêmica | 🟡 | `lib/screens/phonemic_discrimination_screen.dart`, `lib/core/phoneme_map.dart` | Existe |
| Atenção espacial | 🟡 | `lib/screens/spatial_attention_screen.dart`, `lib/core/spatial_controller.dart` | Existe |
| Fala no ruído (Speech-in-Noise) | 🟡 | `lib/screens/speech_in_noise_screen.dart` | Existe |
| Gamificação (XP / Energia Neural / Streak) | 🟡 | `lib/core/gamification_controller.dart` | Existe |
| Relatório clínico / missão | 🟡 | `lib/ui/screens/mission_report_screen.dart`, `lib/services/pdf_service.dart` | Existe |
| Dashboards técnicos/performance | 🟡 | `lib/screens/widgets/performance_dashboard.dart`, `technical_dashboard.dart`, `rehab_trends_chart.dart` | Existe |
| Engine de áudio nativo (DSP/FFI) | 🟡 | `lib/audio_engine/audio_engine.dart`, `lib/audio_engine/native_engine.dart`, `cpp/` | Crítico (latência clínica); sem teste automatizado conhecido |
| TTS (text-to-speech) | ✅ | `lib/services/tts_service.dart`, `assets/audio/` | Resiliência offline com gerador acústico WAV PCM 16-bit autônomo e cache permanente |
| Gatekeeper / paywall (Google Play Billing) | ✅ | `lib/services/gatekeeper_service.dart`, `lib/ui/screens/home_screen.dart` | Desacoplado de Stripe; tiers Pro/Elite, restore purchases e conformidade com Play Store |
| Modelos de domínio | 🟡 | `lib/models/audiogram.dart`, `phonemic_pair.dart`, `rehab_session.dart` | Existe |

## Plataforma & Release
| Feature / fluxo | Estado | Onde (código) | Notas / decisão |
|---|---|---|---|
| Plataforma Android & Play Store Compliance | ✅ | `android/app/build.gradle.kts`, `AndroidManifest.xml`, `proguard-rules.pro`, `cpp/CMakeLists.txt` | Namespace/Application ID `com.bosyn.eartraining`, alinhamento ELF 16 KB (Android 15), permissões saneadas, disclaimer de saúde em `onboarding_screen.dart` |

## Débitos e riscos conhecidos
| Item | Estado | Notas |
|---|---|---|
| `.env` commitado com segredos reais | 🟡 | Untracked do git e adicionado ao `.gitignore`. **Rotação das chaves (Supabase, Google TTS) e limpeza do histórico do git seguem pendentes — ação humana necessária.** |
| Duplicidade `lib/screens/` vs `lib/ui/screens/` | ⬜ | Sintoma de refatoração incompleta; topologia-alvo documentada em `docs/ARCHITECTURE.md` |
| Validação de env em boot (fail-fast) | ⬜ | Módulo 04; fallback gracioso adicionado em `lib/main.dart` |
| Logger estruturado (substituir `print`/`debugPrint`) | ⬜ | Ocorrências em `lib/` para telemetria estruturada |
| Cobertura de testes automatizados | 🟡 | `test/widget_test.dart` corrigido com suíte unitária de `GamificationController` |
| Plataforma iOS ausente | 🚫 | Só `android/`, `web/`, `windows/` existem |
| Erros de compilação em `flutter analyze` | ✅ | **Resolvidos:** `remainingRestTime` adicionado a `GamificationController` e `widget_test.dart` corrigido |
| `dart format` | ⬜ | Reformatar arquivos de `lib/` em lote |
| `flutter test` / `dart run` local | 🟡 | Ambiente local sem MSVC C++ toolchain; roda no CI Ubuntu |

## Regras de uso (deste STATUS)
- **Brownfield:** a auditoria acima confirma existência no código, não corretude. `✅` só para o
  confirmado a fundo; na dúvida, `🟡`/`⬜`.
- **Granularidade:** uma linha por feature de usuário ou fluxo de negócio, não por arquivo.
- **Papéis:** STATUS = estado · DECISIONS = porquê · `#PROJECT_BRAIN.md`/`docs/MASTER_PLAN.md` =
  produto · `.agent/skills/*/SKILL.md` = como. Não fundir estes papéis.
