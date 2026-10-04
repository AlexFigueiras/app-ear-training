# DECISIONS — histórico vivo de decisões
> Entradas no topo (mais recente primeiro). Estado do que existe fica em `docs/STATUS.md`.

## [2026-10-04] Plano "treino eficaz" — Etapa 4 (teste auditivo confiável)
- **Status:** accepted (aguardando CI + checklist no celular)
- **Contexto:** o teste é a âncora do EQ e da seleção de palavras, mas:
  - media através do compressor (corrigido na Etapa 3);
  - não tinha rampa nem tentativas silenciosas;
  - "sempre sim" travava no piso; sem resposta subia até 120 (C1);
  - faltavam 3 e 6 kHz;
  - não cabia em 360×640 (C2);
  - não explicava como responder, mostrava a intensidade ao paciente, trocava de ouvido sem
    aviso e descartava ao voltar (C3);
  - o audiograma saía na ordem do teste, com valores negativos e sem legenda (C4);
  - não dava para refazer.
- **Decisões:**
  - **Procedimento** (`lib/training/threshold_procedure.dart`, Dart puro): Hughson-Westlake
    modificado.
    - Familiarização de 20 em 20; ouviu → -10; não ouviu → +5.
    - Limiar = menor nível com 2 respostas ascendentes.
    - Sem resposta 2× no máximo → "sem resposta".
    - Ouvir no piso conta como ascendente.
    - ~20% de silenciosas; 2 falsos alarmes reiniciam a frequência; 4 encerram como duvidoso.
    - Teto de 30 apresentações.
  - **Achado no teste local:** quem responde "ouvi" para tudo descia ao piso com poucas
    apresentações e passava como confiável em ~88% das vezes. Agora todo limiar só é aceito
    depois de 2 tentativas silenciosas de verificação.
  - **Sessão** (`hearing_test_session.dart`): uma orelha de cada vez, na ordem
    1k-2k-3k-4k-6k-8k-1k(reteste)-500-250. O reteste divergente (> 10 dB) marca a orelha como
    duvidosa. O 1 kHz usa a melhor das duas medidas.
  - **Som:** tom pulsado (3 bipes de 250 ms) sem processamento (bypass) e intervalo irregular
    entre apresentações.
  - **Saída de áudio:** `MainActivity.kt` expõe o canal `bosyn/audio_output` com o volume de
    mídia e o tipo de saída, sem pacote novo.
    - Alto-falante bloqueia o teste; Bluetooth gera aviso.
    - Se o volume mudar no meio, o teste pede para voltar ou recomeçar.
    - Ambiente silencioso: por confirmação da pessoa. Medir o ruído exigiria permissão de
      microfone; não foi adicionada.
  - **Tela:** instruções → som de treino → aviso de cada ouvido → "Ouvi"/"Não ouvi" → resultado.
    - Sem intensidade visível.
    - Sair no meio pede confirmação.
    - Tudo rolável.
  - **Resultado:** audiograma clínico (250 → 8 k, nível de cima para baixo, valores positivos,
    legenda ×/○, "sem resposta" listado).
    - Categoria OMS 2021 aproximada por PTA4, sempre com "estimativa, não é exame".
    - Próximo passo: refazer (respostas inconsistentes), procurar profissional (assimetria
      ≥ 15 dB, PTA4 ≥ 35 ou sem resposta) ou começar a treinar.
  - **Versionamento:** `AudiometryPoint` ganhou `no_response`, `reliable` e `protocol` (2). Os
    pontos antigos leem como protocolo 1.
    - Ao abrir um treino com audiograma antigo, o app oferece refazer
      (`HearingTestFlow.ensureCurrent`).
    - O "Refazer teste de audição" da Home já existe (sessão da auditoria) e abre a tela nova,
      porque o contrato de retorno `{left, right}` foi mantido. Esta etapa não editou a Home.
- **Critério do plano revisado:** "±5 dB em 95%" não é atingível com passos de 5 dB, nem na
  audiometria clínica. Em simulação (20 mil execuções, limiar uniforme em -5..65), o método dá
  ~80% a ±5 dB, ~100% a ±10 dB, erro médio ~3 dB e viés de +2,7 dB (estima perto do ponto de
  70% de detecção). O teste trava esses números.
- **Verificação:** os testes Dart puros (`threshold_procedure_test`, `hearing_test_session_test`,
  `tone_factory_test`, `audibility_profile_test`) rodaram localmente com `dart` e um substituto
  mínimo de `flutter_test` (o `flutter test` não roda nesta máquina): 20/20 ok. `flutter analyze`
  limpo.
- **Arquivos:**
  - `lib/training/threshold_procedure.dart`, `hearing_test_session.dart`,
    `hearing_summary.dart`;
  - `lib/screens/threshold_test_screen.dart` e `lib/screens/hearing_test/*`;
  - `lib/services/audio_output_service.dart`, `MainActivity.kt`;
  - `lib/models/audiogram.dart`, `lib/audio_engine/{audio_engine,tone_factory}.dart`;
  - as 3 telas de treino (checagem de audiograma antigo);
  - `lib/screens/widgets/phonemic_widgets.dart` (extraído para a tela ficar abaixo de 300
    linhas);
  - testes.
- **Pendente para depois:** E4 (calibração "−200 ms") e E5 (modo engenheiro por toque longo)
  ficam para a varredura da Etapa 11.

## [2026-10-04] Plano "treino eficaz" — Etapa 3 (motor C++ consertado, mantido em C++)
- **Status:** accepted (aguardando CI + checklist no celular)
- **Contexto:** a cadeia nativa estava quebrada e distorcia até a medição.
  - `pffft.c` era um placeholder de FFT.
  - `PartitionedFIR` estourava `overlapBuffer` a cada bloco do callback (heap overflow).
  - O "TEE" (γ=0,7) era um compressor rápido aplicado a tudo, inclusive aos tons do teste:
    tons fracos ganhavam até +24 dB e a perda em agudos saía subestimada.
  - O EQ era um único peaking na "pior" frequência, com a média das orelhas.
  - Os ganhos do paciente eram um volume de banda larga com teto de 4×.
  - O ruído passava pelo EQ, então o SNR não era o pedido.
  - O `SamplePlayer` tinha corrida de dados (o Dart chamava `clear()` enquanto o áudio lia) e
    `setLoop` não fazia nada.
- **Decisão do usuário:** manter o motor em C++/Oboe e consertá-lo.
- **Arquitetura nova** (`cpp/`, sem dependência nova):
  - **Mixer:** `AudioGraph` (sem Oboe, testável no host). Alvo → EQ por orelha (ou bypass) →
    pan; masker e ruído entram depois do EQ; limitador -1 dBFS no fim.
  - **EQ:** `eq_bank.h`, EQ de 8 bandas (250 Hz–8 kHz) de biquads por orelha. O projeto ajusta
    iterativamente os ganhos dos filtros para a resposta medida bater com o alvo.
  - **Fontes de som:** `buffer_source.h` + `handoff.h`. Troca de buffer e de coeficientes por
    ponteiro atômico: a thread de áudio nunca aloca nem libera. Loop real, fade de 5 ms ao
    silenciar.
  - **Limitador:** `safety_limiter.h`, ataque instantâneo, liberação de 50 ms. Conta os
    acionamentos, que aparecem no painel.
  - **Ponte FFI:** `set_eq_targets`, `set_dsp_bypass`, `get_limiter_hits`,
    `reset_limiter_hits`, `get_target_frames_remaining`, `set_masker_gain`. Removidos
    `set_test_tone`, `set_audiogram_profile` e `consume_soft_knee_flag`.
  - **Apagados:** `dsp_engine.*`, `fir_filter.*`, `pffft.*`, `tee_processor.h`,
    `sample_player.h`, `sine_oscillator.h`, `noise_generator.h`, `test_ringbuffer.cpp`.
- **Dart:**
  - `AudibilityProfile`: ganho por orelha = meio ganho da perda relativa à melhor frequência da
    orelha, teto de 25 dB, com 3 k/6 k interpolados em escala log.
  - O boost de dificuldade da Fonêmica vale só nas bandas ≥ 3 kHz (antes era volume de banda
    larga).
  - `SignalLevel` normaliza a fala a -30 dBFS RMS, e o ruído do Coquetel sai no SNR pedido,
    inclusive abaixo de 0 dB.
  - Tons de teste e de calibração usam bypass.
  - Os lookups de FFI são guardados uma vez só.
  - Painel técnico com QA de áudio (debug/profile): tons por orelha, a mesma palavra com e sem
    EQ, contador do limitador.
- **Desvio do plano:** o boost é composto em Dart e vai junto com o perfil em
  `set_eq_targets`, em vez de um `set_high_band_boost_db` nativo. Fica um símbolo a menos e a
  regra é testável em Dart.
- **Testes:**
  - `cpp/tests/eq_test.cpp`: erro ≤ 1,5 dB por banda em perfis descendente, entalhe em 4 k e
    boost agudo.
  - `graph_test.cpp`: bypass = identidade, EQ só no alvo, ruído fora do EQ, pan, limitador
    ≤ -1 dBFS, silêncio com fade, loop sem emenda, zero alocação no render.
  - `graph_threads_test.cpp`: estresse com duas threads, sob TSan.
  - `test/audibility_profile_test.dart`.
  - CI: os testes nativos rodam com ASan/UBSan e também com ThreadSanitizer.
- **Consequências:**
  - O audiograma antigo foi medido com o compressor e subestima a perda em agudos; a Etapa 4
    pede reteste.
  - O ruído do Coquetel segue branco até a Etapa 7.
- **Nota de processo:** outra sessão (auditoria de UX, etapa B do onboarding) trabalha na mesma
  pasta. O commit desta etapa inclui só os arquivos dela.

## [2026-10-04] Plano "treino eficaz" — Etapa 2 (áudio que sai errado)
- **Status:** accepted (aguardando CI + checklist no celular; deploy da função `tts` é ação
  humana)
- **Contexto:**
  - A voz tocava uma oitava acima e com o dobro da velocidade: a função `tts` não pedia taxa
    (WaveNet = 24 kHz), e o app pulava 44 bytes fixos e tocava a 48 kHz.
  - O ruído do Coquetel nunca desligava, e o motor é compartilhado.
  - O pan de uma tela anterior (±1) fazia a palavra da Fonêmica tocar num ouvido só.
  - A resposta era liberada antes de a palavra terminar.
  - O "Repetir" estava invertido.
  - O log do Coquetel gravava o SNR já atualizado.
  - A calibração travava, porque o símbolo nativo `get_current_timestamp_ns` não existia.
  - O tom de calibração saía em escala cheia, e o tom do teste podia passar de 1,0.
  - Havia log (`std::cerr`) dentro do callback de áudio.
  - Blocos acima de 1024 frames saíam sem processamento.
  - Ao desplugar o fone, o motor reiniciava e seguia tocando no alto-falante.
- **Decisões:**
  - **Voz:**
    - `supabase/functions/tts` pede `sampleRateHertz: 48000`.
    - `lib/audio_engine/wav_decoder.dart` percorre os chunks RIFF, lê a taxa real e reamostra
      com sinc janelado (Blackman). Assim o app funciona antes e depois do deploy.
    - Cache com chave `v2|48000|…` na pasta de suporte, não na temporária.
  - **Silêncio:**
    - Novo símbolo nativo `silence_all` (alvo, ruído e tom), chamado no `dispose` de todas as
      telas de treino e no fim do Coquetel.
    - `AudioLifecycleGuard` silencia quando o app sai da frente.
    - O evento "becoming noisy" (fone desplugado) silencia em vez de reiniciar.
    - Estímulos sem ruído zeram o ruído e centralizam o pan.
  - **Resposta:** cada `play*` devolve a duração do estímulo; a tela só libera a resposta
    quando a palavra termina. O "Repetir" fica ativo quando não há nada tocando. Falha de rede
    mostra aviso em vez de travar a tela.
  - **Tons:** `ToneFactory` com rampa cosseno de 20 ms; calibração a -20 dBFS; teto no nível
    do tom do teste.
  - **Nativo:**
    - sem log no callback;
    - `DspEngine` processa em pedaços;
    - `get_current_timestamp_ns` usa o mesmo relógio (`steady_clock`) do onset.
- **Testes:** `test/wav_decoder_test.dart` (24k→48k mantendo altura e duração, chunk extra de
  tamanho ímpar, estéreo, PCM cru, formato inválido) e `test/tone_factory_test.dart`.
- **Consequências:**
  - O ganho de banda larga com teto de +12 dB segue provisório até a Etapa 3.
  - O teste auditivo antigo segue impreciso até a Etapa 4.
  - `threshold_test_screen.dart` foi a 346 linhas líquidas (aviso); a Etapa 4 o reescreve.

## [2026-10-04] Plano "treino eficaz" — Etapa 1 (limpeza e promessas)
- **Status:** accepted (aguardando CI + checklist no celular)
- **Contexto:** havia código órfão que chama APIs do motor que mudam na Etapa 3, e um PDF
  "clínico" com números inventados. O app também prometia o que o treino não faz ("remapear
  frequências agudas perdidas"; "restauração da audição" no `docs/MASTER_PLAN.md`). E as skills
  que orientam agentes prescreviam o desenho de DSP quebrado.
- **Decisões:**
  - **Código órfão removido:** `training_dashboard`, `mission_report_screen`, `pdf_service`
    (com as deps `pdf`/`printing`), `spatial_controller` (e o provider em `main.dart`),
    `performance_dashboard`, `rehab_trends_chart`, `phonemic_pair`, além dos 70 placeholders
    de `phoneme_map.dart`.
  - **Promessas trocadas por texto honesto:**
    - página "COMO FUNCIONA" no onboarding: o treino "não recupera a audição perdida";
    - Home: "TREINO AUDITIVO" e "ACERTOS NAS ÚLTIMAS SESSÕES";
    - título do app e descrição do pubspec;
    - §1 do `docs/MASTER_PLAN.md`;
    - comentários que citavam evidência de dose inexistente.
  - **"Pular teste"** conclui o onboarding sem abrir o teste. A Home já exige o teste antes do
    primeiro treino.
  - **Skills (`.agent/skills` e a cópia em `.claude/skills`):**
    - `DSP_AUDIO_ENGINE` reescrita para a arquitetura-alvo: EQ de biquads por orelha, ruído
      mixado depois do EQ, bypass para medição, regras de tempo real;
    - `AUDIOLOGIA_CLINICA` ganhou um aviso de limites da evidência;
    - removidos a tabela TR→ERP, o par homófono Sinto/Cinto e a descrição de γ<1 como
      "expansão";
    - o banco de pares passa a priorizar ponto de articulação e /s/ final.
  - **Base de texto acessível:** `lib/ui/theme/bosyn_text.dart` (mínimo 14) e
    `docs/GLOSSARIO_UI.md`.
- **Arquivos impactados:** os removidos acima, `lib/main.dart`,
  `lib/core/gamification_controller.dart`, `lib/core/phoneme_map.dart`,
  `lib/ui/screens/onboarding_screen.dart`, `lib/ui/screens/home_screen.dart`, 3 telas de treino
  (comentários), `pubspec.yaml`/`.lock`, `docs/MASTER_PLAN.md`, skills, `docs/STATUS.md`.
- **Consequências:** o treino em si ainda não mudou (a memorização continua até a Etapa 5).
- **Gotcha de histórico:** as remoções de arquivos desta etapa entraram por engano no commit de
  CI `9cffee7`, porque estavam staged quando ele foi feito. Esse commit isolado não compila
  (`main.dart` ainda importava `spatial_controller`). O commit da Etapa 1 restaura a
  consistência. O histórico não foi reescrito porque o branch já estava publicado.

## [2026-10-04] Plano "treino eficaz" aprovado — Etapa 0 (base verde)
- **Status:** accepted (Etapa 0 aguardando CI + checklist no celular)
- **Contexto:** a análise do treino mostrou que ele não melhora a percepção de consoantes
  agudas:
  - a resposta de cada par é memorizável, porque só o alvo toca e cada par tem resposta fixa;
  - metade do banco treina vozeamento/nasalidade, que são pistas graves;
  - o "boost" satura no clamp de 4×;
  - a cadeia DSP nativa está quebrada (`pffft.c` é placeholder e `PartitionedFIR` estoura
    `overlapBuffer` no callback) e distorce até o teste auditivo (o "TEE" com γ=0,7 é um
    compressor);
  - o TTS chega a 24 kHz e toca a 48 kHz;
  - o ruído do Coquetel nunca desliga;
  - o Espacial é monaural;
  - o XP dobra nas tarefas fáceis e o "nível de acuidade" é só XP.
- **Decisões do usuário:**
  - Verificar cada etapa por CI + APK no celular.
  - Redesenhar o Espacial.
  - Trocar a Energia Neural por limite de tempo.
  - Progressão por domínio, mantendo o PRO.
  - **Manter o motor em C++/Oboe e consertá-lo**, trocando FIR/FFT/TEE por EQ de biquads, o
    que não exige biblioteca nova.
  - Commitar antes o trabalho pendente da Play (commit `6e92873`).
- **Etapa 0:**
  - `flutter analyze` foi de 51 issues para 0, com correções mecânicas (`withOpacity` →
    `withValues`, imports e campos sem uso, `final`/`const`, `phonemeRehabData`, `mounted`
    antes de `Navigator.pop`).
  - `AudioDeviceType` ganhou um `ignore` justificado.
  - `ffi` e `shared_preferences` foram declarados no pubspec. Já eram usados por dependência
    transitiva, então nenhum pacote novo entra no app; aprovado pelo usuário no plano.
  - Job novo `native-tests` no CI: compila `cpp/tests/*_test.cpp` no host com ASan/UBSan.
    Primeiro teste: resposta em frequência dos biquads, que serão a base do EQ da Etapa 3.
  - O CI passa a gerar também o APK de **profile**, usado no checklist de escuta (o debug roda
    em JIT e distorce tempo e fluidez).
- **Arquivos impactados:** `pubspec.yaml`, `pubspec.lock`, `.github/workflows/ci.yml`,
  `cpp/tests/check.h`, `cpp/tests/biquad_test.cpp`, ~17 arquivos de `lib/` (só correções do
  analyzer), `docs/STATUS.md`.
- **Consequências:**
  - Nenhum comportamento do app muda nesta etapa.
  - O plano completo fica em STATUS (seção "Plano treino eficaz").
  - As etapas seguintes só começam depois do "ok" do usuário no checklist.

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
