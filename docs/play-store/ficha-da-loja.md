# Ficha da loja — BOSYN (Google Play)

> Textos da página da loja (Missões 6c e 8 da skill de publicação), contados por código. A Folha
> de Respostas (https://claude.ai/artifact/KynF31YyaytfpXmA47wYD7; fonte em
> `docs/play-store/folha-de-respostas.html`) tem os mesmos textos com botão Copiar.
> Regras da Play para app de saúde: `docs/PLAY_STORE.md`, seção 4.

## Nome do app (22/30)

```text
BOSYN: Treino Auditivo
```

## Descrição breve (78/80)

```text
Treino auditivo com fones: palavras parecidas e fala no barulho, no seu ritmo.
```

## Descrição completa (2426/4000)

```text
O BOSYN é um programa de treino auditivo para quem quer entender melhor a fala, principalmente em lugares com barulho. Você treina com fones de ouvido, alguns minutos por dia, e o app se ajusta ao seu jeito de ouvir.

COMO FUNCIONA
Primeiro, um teste de audição de uns 10 minutos, feito com o seu fone, mostra quais sons ficam mais difíceis para você. Depois, os treinos dão mais atenção a esses sons. A dificuldade sobe e desce sozinha: fica sempre na medida para você continuar aprendendo, sem desanimar.

OS TREINOS
- Palavras parecidas: ouça uma palavra e escolha entre duas parecidas, como "sala" e "fala". Grátis.
- Conversa no barulho: entenda palavras com ruído de fundo, como num restaurante.
- Voz de um lado, barulho do outro: entenda a voz que vem de um lado com barulho do outro, como numa mesa cheia.
Depois de cada resposta, o app mostra se você acertou e deixa ouvir as duas palavras de novo.

SEU PROGRESSO
Uma meta de 15 minutos por dia, dias seguidos de treino e o nível de cada treino. A cada 14 dias, um teste rápido de números no barulho mostra se você está entendendo melhor a fala. É uma medida interna do app, não um exame clínico.

PLANO PRO OU VÍDEO
O treino "Palavras parecidas" é grátis. Os treinos com barulho fazem parte do plano PRO, por assinatura mensal ou anual pelo Google Play, que também tira os anúncios. Cancele quando quiser no Google Play. Quem não assina pode liberar uma sessão desses treinos assistindo a um vídeo curto, algumas vezes por dia. No plano grátis aparece um anúncio pequeno na tela inicial, nunca durante um teste ou um treino.

FEITO PARA LER E OUVIR COM CONFORTO
Letras grandes, bom contraste, botões grandes e compatível com o leitor de tela. Tudo em português.

SEUS DADOS
Os resultados dos seus testes e treinos ficam na sua conta, protegidos, e nunca são usados para anúncios. Você pode excluir a conta e todos os dados pelo próprio app.

IMPORTANTE
O BOSYN não é um dispositivo médico e não diagnostica, trata, cura nem previne doenças. O teste de audição do app é uma estimativa feita com o seu fone, usada só para ajustar o treino, e não substitui a avaliação de um fonoaudiólogo ou de um médico otorrinolaringologista. Use fones de ouvido e um volume confortável. Se você notar perda auditiva súbita, zumbido persistente, dor ou tontura, procure um profissional.

Coloque os fones e comece pelo teste de audição. Uns minutos por dia já fazem parte do treino.
```

A descrição cumpre o que a Play exige de app de saúde: diz que não é dispositivo médico e não
diagnostica, trata, cura nem previne doenças; recomenda procurar um profissional; avisa que é
preciso usar fones; não promete resultado clínico. Também conta, sem esconder, o que é grátis, o
que é assinatura e onde aparecem os anúncios.

## Notas da versão (primeira versão)

```text
<pt-BR>
Primeira versão do BOSYN! Treino auditivo com fones: palavras parecidas e fala no barulho, no seu ritmo.
</pt-BR>
```

## Imagens (pasta `docs/play-store/loja/`)

| Campo da Play Console | Arquivo | Situação |
|---|---|---|
| Ícone do app (512×512, até 1 MB) | `icone-512.png` | pronto |
| Recurso gráfico (1024×500) | `recurso-grafico-1024x500.png` | pronto |
| Capturas de tela do telefone (2 a 8, 9:16) | `captura-1.png` … | **falta**: tirar no celular com a versão de teste interno (veja abaixo) |

Arte-fonte do ícone: `icone-bosyn.svg` (o mesmo desenho do ícone do app no Android).

### Capturas de tela

A Play recusa captura que não mostra o app de verdade. Tire 4 a 6 no celular, com a versão
instalada pelo teste interno (Missão 9A), nesta ordem:

1. Tela inicial com o "Treino de hoje" e a meta do dia.
2. "Palavras parecidas" no meio de uma tentativa (as duas palavras na tela).
3. Retorno de erro com "Ouvir as duas".
4. "Conversa no barulho" com as 4 opções.
5. Resultado do teste de audição (audiograma).
6. "Meu progresso".

Não mostre a faixa de anúncio nem dados pessoais (e-mail) nas capturas. Para pôr legenda e
fundo nas capturas (molduras 1080×1920), mande os arquivos numa conversa e peça "molduras".

## Configurações da loja

- App ou jogo: **App**.
- Categoria: **Medicina**. A Play trata treino auditivo como app médico (`docs/PLAY_STORE.md`,
  Veredito). Se o formulário de apps de saúde indicar outra, siga o formulário.
- Tags: escolha até 5 entre as que a Play oferecer para Medicina e Saúde (ex.: saúde auditiva,
  bem-estar). Confira no print.
- E-mail de contato: **contato@bosyn.com.br**.
- Site: **https://alexfigueiras.github.io**. É onde o AdMob procura o `app-ads.txt`.
- Telefone: pode ficar vazio.
- Política de privacidade: **https://alexfigueiras.github.io/politica-bosyn.html**.
