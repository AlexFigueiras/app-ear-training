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
| Home / dashboard de treino | 🟡 | `lib/ui/screens/home_screen.dart`, `lib/ui/screens/training_dashboard.dart` | Existe **duplicidade estrutural**: há uma segunda árvore de telas em `lib/screens/` paralela a `lib/ui/screens/` — não resolvida neste bootstrap (decisão que toca `lib/`, fora de escopo, ver `docs/ARCHITECTURE.md`) |
| Teste de limiar tonal (Threshold Test) | 🟡 | `lib/screens/threshold_test_screen.dart` | Existe |
| Discriminação fonêmica | 🟡 | `lib/screens/phonemic_discrimination_screen.dart`, `lib/core/phoneme_map.dart` | Existe |
| Atenção espacial | 🟡 | `lib/screens/spatial_attention_screen.dart`, `lib/core/spatial_controller.dart` | Existe |
| Fala no ruído (Speech-in-Noise) | 🟡 | `lib/screens/speech_in_noise_screen.dart` | Existe |
| Gamificação (XP / Energia Neural / Streak) | 🟡 | `lib/core/gamification_controller.dart` | Existe |
| Relatório clínico / missão | 🟡 | `lib/ui/screens/mission_report_screen.dart`, `lib/services/pdf_service.dart` | Existe |
| Dashboards técnicos/performance | 🟡 | `lib/screens/widgets/performance_dashboard.dart`, `technical_dashboard.dart`, `rehab_trends_chart.dart` | Existe |
| Engine de áudio nativo (DSP/FFI) | 🟡 | `lib/audio_engine/audio_engine.dart`, `lib/audio_engine/native_engine.dart`, `cpp/` | Crítico (latência clínica); sem teste automatizado conhecido |
| Telemetria / persistência Supabase | 🟡 | `lib/services/supabase_service.dart`, `lib/services/event_buffer.dart`, `lib/models/rehab_session.dart` | Existe; políticas RLS reais não auditadas (schema fora do repo) |
| TTS (text-to-speech) | 🟡 | `lib/services/tts_service.dart` | Existe; depende de `GOOGLE_TTS_API_KEY` (ver incidente de segredo abaixo) |
| Gatekeeper / paywall (Stripe) | 🟡 | `lib/services/gatekeeper_service.dart`, dep. `flutter_stripe` | Existe |
| Modelos de domínio | 🟡 | `lib/models/audiogram.dart`, `phonemic_pair.dart`, `rehab_session.dart` | Existe |

## Débitos e riscos conhecidos (não corrigidos neste bootstrap, por estarem fora do escopo "não tocar em lib/código")
| Item | Estado | Notas |
|---|---|---|
| `.env` commitado com segredos reais | 🟡 | Untracked do git e adicionado ao `.gitignore` neste bootstrap. **Rotação das chaves (Supabase, Google TTS) e limpeza do histórico do git seguem pendentes — ação humana necessária.** |
| Duplicidade `lib/screens/` vs `lib/ui/screens/` | ⬜ | Sintoma de refatoração incompleta; não resolvida — decisão que toca `lib/`, fora do escopo deste bootstrap |
| Validação de env em boot (fail-fast) | ⬜ | Módulo 04 do kit original; exige tocar `lib/main.dart` — follow-up, não executado |
| Logger estruturado (substituir `print`/`debugPrint`) | ⬜ | 29 ocorrências em `lib/` na auditoria de 2026-07-18; módulo 05 reduzido, follow-up |
| Cobertura de testes automatizados | ⬜ | Apenas `test/widget_test.dart` existe; sem suíte real para ~5.000 linhas de `lib/` |
| Arquivos soltos na raiz (`analysis.txt`, `build_log.txt`, `debug_env.log`, `write_test.txt`) | ⬜ | Lixo de debug versionado; não removido neste bootstrap (decisão do usuário, não higiene automática) |
| Plataforma iOS ausente | 🚫 | Só `android/`, `web/`, `windows/` existem; fora de escopo deste bootstrap (decisão de stack/plataforma, não de governança) |
| `skills-library/CATALOG.md` | 🟡 | Catálogo genérico de ~1.262 skills de mercado, **não curado para este projeto** (confirmado por leitura: contém skills de Angular, Godot, Elixir etc., sem relação com Flutter/audiologia). Distinto de `.agent/skills/`, que É específico deste projeto. Ver `docs/DECISIONS.md`. |
| **2 erros reais em `flutter analyze`** (pré-existentes, não introduzidos por este bootstrap) | ⬜ | `error - The getter 'remainingRestTime' isn't defined for the type 'GamificationController' - lib/ui/screens/training_dashboard.dart:487` · `error - The name 'MyApp' isn't a class - test/widget_test.dart:16` (a única suíte de teste do projeto não compila). Descobertos ao endurecer o CI (módulo 11) — `flutter analyze` já falhava antes deste bootstrap independentemente das flags `--no-fatal-*`, porque erros (diferente de warnings/infos) sempre são fatais. Não corrigidos aqui (toca `lib/`/`test/`, fora de escopo). |
| `dart format` — 29 dos 33 arquivos `.dart` de `lib/` não estão formatados no padrão `dart format` | ⬜ | Descoberto ao tentar endurecer o step "Verify formatting" do CI. Reformatar é whitespace-only, mas toca todo `lib/` — mantido como `continue-on-error: true` no CI por decisão explícita (ver `.github/workflows/ci.yml` e `docs/DECISIONS.md`), não corrigido neste bootstrap. |
| `flutter test` / `dart run` não executam localmente nesta máquina | 🟡 | Falta toolchain de compilador C (Visual Studio Build Tools/MSVC) para o build de native assets do pacote `win32` (dependência transitiva). Não é causado por este bootstrap; não deve reproduzir no CI (`ubuntu-latest` tem `gcc`/`build-essential` por padrão). `tool/verify_rules.dart` foi validado com sucesso via `dart run` várias vezes **antes** desta limitação aparecer (ver histórico de testes negativos dos módulos 06/10 em `docs/DECISIONS.md`). |

## Regras de uso (deste STATUS)
- **Brownfield:** a auditoria acima confirma existência no código, não corretude. `✅` só para o
  confirmado a fundo; na dúvida, `🟡`/`⬜`.
- **Granularidade:** uma linha por feature de usuário ou fluxo de negócio, não por arquivo.
- **Papéis:** STATUS = estado · DECISIONS = porquê · `#PROJECT_BRAIN.md`/`docs/MASTER_PLAN.md` =
  produto · `.agent/skills/*/SKILL.md` = como. Não fundir estes papéis.
