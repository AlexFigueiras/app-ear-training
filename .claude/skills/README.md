# .claude/skills/ — sincronizado de .agent/skills/

**Não edite os `SKILL.md` aqui diretamente.** A fonte de verdade é `.agent/skills/`. Esta cópia
existe porque o Claude Code descobre skills em `.claude/skills/`, e até este bootstrap
`.agent/skills/` (13 skills, incluindo as específicas do projeto `AUDIOLOGIA_CLINICA` e
`DSP_AUDIO_ENGINE`) não estava exposto ali — nenhuma dessas skills aparecia como disponível numa
sessão nova do Claude Code.

## Como isso foi feito
Cópia manual, uma vez (`cp -r .agent/skills/. .claude/skills/`), em 2026-07-18. O kit
`bootstrap/09-generate-full.md`/`14-skills.md` original prevê um comando `generate sync-skills`
que mantém isso sincronizado automaticamente a cada commit — esse gerador **não foi construído
neste bootstrap** (não há `domains/` físico para gerar a partir; ver
`bootstrap/PLANO-VIABILIDADE-E-ADOCAO.md` e módulos 08/09 em `MASTER-PLAN.md`).

## Consequência prática
Se você editar algo em `.agent/skills/<skill>/SKILL.md`, replique manualmente em
`.claude/skills/<skill>/SKILL.md` (ou rode `cp -r .agent/skills/. .claude/skills/` de novo) até
que um gerador automático exista. Registre a decisão de construir esse gerador em
`docs/DECISIONS.md` quando/se isso acontecer.

## Escopo
Apenas `.claude/skills/` foi criado. `.gemini/skills/` (mencionado no kit original) não foi
criado — não há evidência de uso do Gemini CLI neste projeto; criar essa pasta seria inventar
infraestrutura sem uso real.
