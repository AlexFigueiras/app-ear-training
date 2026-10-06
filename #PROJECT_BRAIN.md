# Plano Diretor de Desenvolvimento (PRD) — BOSYN, app de treino auditivo
**Role Ativa:** [ORQUESTRADOR]

## 1. Visão de produto [MASTER_PLAN]
App mobile de **treino auditivo** para a percepção de consoantes agudas e da fala no ruído.
**Não é dispositivo médico e não recupera a audição**: ensina a aproveitar melhor as pistas que
ainda chegam ao ouvido.

As regras de produto (treinos, gamificação, medida de progresso, acessibilidade) estão em
`docs/MASTER_PLAN.md`; o porquê de cada uma, em `docs/DECISIONS.md` (plano "treino eficaz",
Etapas 0–12).

## 2. Caminho crítico BOSYN (Golden Rules)
1. Antes de qualquer código, validar o `docs/MASTER_PLAN.md` e ler o `docs/STATUS.md`.
2. **Evidência antes de efeito.** Toda mecânica de treino precisa de base na literatura (pista
   audível, várias vozes, escada adaptativa ~79%, feedback, dose em minutos) e de teste
   automatizado da regra. Toda promessa ao paciente precisa ser honesta: sem "restaurar",
   "recuperar" ou "curar".
3. **Áudio seguro:** silêncio ao sair de qualquer tela, ao ir para segundo plano e ao
   desconectar o fone (`AudioServiceManager().silenceAll()` / `AudioLifecycleGuard`). Medição sem
   processamento (bypass).
4. **Acessibilidade sênior travada por máquina:** fonte ≥ 14, contraste AA, telas roláveis com
   fonte em 200%, pt-BR (`verify_rules` + `test/large_font_test.dart`).

## 3. Os treinos (estado atual)
- **Palavras parecidas:** pares mínimos reais por ponto de articulação (s×ch, s×f, t×p, t×k, /s/
  final); qualquer palavra do par pode tocar; dificuldade = reforço só nos agudos.
- **Conversa no barulho:** 4 opções (sala/fala/salas/falas) na frase "Diga ___ agora", com
  ruído de fala ou burburinho de 6 vozes e SNR adaptativo exato.
- **Voz de um lado, barulho do outro:** a mesma tarefa com a voz a ±60° e o burburinho do outro
  lado (diferença de tempo entre orelhas + sombra da cabeça no motor nativo).
- **Teste de audição:** triagem relativa (Hughson-Westlake modificado com tentativas
  silenciosas, 250 Hz–8 kHz). É a âncora do EQ por orelha e da escolha de palavras.
- **Audição na fala:** teste de dígitos no ruído a cada 14 dias. É a medida de progresso, com
  material que o treino não usa.

A Fonêmica é grátis; os treinos com ruído fazem parte do plano PRO (ainda não à venda).

## 4. Stack técnica
- **Frontend:** Flutter/Dart (Android; iOS fora de escopo por ora). Regras de domínio em Dart puro
  (`lib/training/`), com testes.
- **Áudio:** motor nativo C++/Oboe via FFI (`cpp/`): mixer `AudioGraph`, EQ de biquads por
  orelha, espacializador, limitador. Testado no host com sanitizers no CI.
- **Backend:** Supabase (Auth + Postgres com RLS por `user_id`). Edge Functions para o que exige
  segredo (`tts`, `delete-account`).
- **Monetização:** PRO "em breve"; venda só com Google Play Billing validado no servidor (ver
  `docs/PLAY_STORE.md`).

## 5. Gestão de Skills e Bibliotecas Externas
De acordo com as diretrizes globais do projeto:
*   A consulta de novas habilidades deve ser feita **estritamente via arquivo `skills-library/catalog.md`**.
*   Os arquivos de implementação de skills estão localizados em `skills-library/archives/` para otimização de contexto. O agente deve ignorar recursivamente qualquer conteúdo dentro desta pasta.
*   **Atenção:** Não tentar ler ou indexar nada dentro de `archives/` por conta própria. A implementação específica será solicitada pelo usuário com o caminho exato do arquivo, caso seja necessária a sua utilização.

## 6. Aviso de saúde
> O BOSYN é um programa de treino auditivo. Não é um dispositivo médico, não faz diagnóstico e não
> substitui a avaliação de um fonoaudiólogo ou médico otorrinolaringologista. O teste auditivo do
> app é uma estimativa feita com o seu fone, usada só para personalizar o treino.

O texto exibido no app fica em `lib/core/legal_documents.dart`. O antigo "aviso de suporte à
decisão clínica" saiu: contradizia o posicionamento de não ser dispositivo médico (ANVISA RDC
657/2022, ver `docs/PLAY_STORE.md`).

---
**Status atual:** ver `docs/STATUS.md` (seção "Plano treino eficaz").

**Próximos passos:**
1. Teste no celular das Etapas 2–11 (fone com fio; TalkBack).
2. Revisão por fonoaudiólogo do banco de palavras e dos textos de orientação.
3. Etapa 13 (opcional): rebaixamento de frequência, só com validação profissional.
4. Ações humanas: deploy da Edge Function `tts`, rotação de chaves, migration 003.


5. Gestão Proativa de Skills
Para maximizar a eficiência e evitar reencapsulamento de código:

Consulta Obrigatória: Antes de qualquer implementação, o agente deve escanear o skills-library/catalog.md.

Gatilho de Ação (Proatividade): Se uma skill relevante for encontrada, o agente deve interromper o raciocínio e dizer: "Identifiquei que a skill [NOME-DA-SKILL] resolve esta tarefa. Por favor, forneça o conteúdo do arquivo archives/nome_da_skill.dart para que eu possa aplicar a lógica (X-Copy)."

Manutenção: Ao criar uma solução inédita e robusta, o agente deve sugerir ao [ORQUESTRADOR] a criação de uma nova entrada no catálogo.
