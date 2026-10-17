#!/usr/bin/env bash
# Monta o .env do build de release (lido com --dart-define-from-file) e confere cada valor antes
# de gastar 10 minutos de build. Nada daqui é segredo: tudo vai dentro do app (AGENTS.md seção 7)
# — por isso uma chave secreta do Supabase é recusada.
# Usado pelo botão "2 - Gerar AAB" (.github/workflows/2-gerar-aab.yml).
#
# Entradas (variáveis de ambiente): ANUNCIOS (teste | reais), SUPABASE_URL,
# SUPABASE_PUBLISHABLE_KEY, ADMOB_APP_ID, ADMOB_BANNER_ID, ADMOB_REWARD_ID.
# Saídas ($GITHUB_OUTPUT): modo (TESTE | REAIS) e admob_app_id (o que deve estar no manifesto).
set -euo pipefail

ADMOB_TEST_APP_ID="ca-app-pub-3940256099942544~3347511713"
POLITICA="docs/legal/politica-de-privacidade.md"

resumo() { if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "$1" >> "$GITHUB_STEP_SUMMARY"; fi; }
erro() {
  echo "::error::$1"
  resumo "❌ $1"
  exit 1
}
aviso() {
  echo "::warning::$1"
  resumo "⚠️ $1"
}
saida() { if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; }

# Payload de um JWT (base64url) em texto.
jwt_payload() {
  local s
  s=$(printf '%s' "$1" | cut -d. -f2)
  s="${s//-/+}"
  s="${s//_//}"
  while [ $(( ${#s} % 4 )) -ne 0 ]; do s="$s="; done
  printf '%s' "$s" | base64 -d 2>/dev/null || true
}

# 1. Supabase (endereço e chave pública do projeto)
URL="${SUPABASE_URL:-}"
KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
[ -n "$URL" ] || erro "Falta o segredo SUPABASE_URL (https://<projeto>.supabase.co)."
case "$URL" in
  https://*) ;;
  *) erro "SUPABASE_URL precisa começar com https:// (ex.: https://<projeto>.supabase.co)." ;;
esac
[ -n "$KEY" ] || erro "Falta o segredo SUPABASE_PUBLISHABLE_KEY (a chave sb_publishable_… do Supabase)."
case "$KEY" in
  sb_publishable_*) ;;
  sb_secret_*)
    erro "SUPABASE_PUBLISHABLE_KEY é uma chave SECRETA (sb_secret_…): ela nunca pode ir para o app. Use a sb_publishable_…" ;;
  *.*.*)
    if ! jwt_payload "$KEY" | grep -Eq '"role"[[:space:]]*:[[:space:]]*"anon"'; then
      erro "SUPABASE_PUBLISHABLE_KEY é um JWT que não é a chave anon (talvez a service_role): ela nunca pode ir para o app."
    fi
    aviso "SUPABASE_PUBLISHABLE_KEY é a chave anon legada: o Supabase desliga as legadas no fim de 2026. Troque pela sb_publishable_…" ;;
  *) erro "SUPABASE_PUBLISHABLE_KEY não parece uma chave do Supabase (esperado sb_publishable_…)." ;;
esac

# 2. Anúncios: IDs reais só quando pedido; senão o app usa os IDs de teste do Google.
if [ "${ANUNCIOS:-teste}" = "reais" ]; then
  APP="${ADMOB_APP_ID:-}"
  BANNER="${ADMOB_BANNER_ID:-}"
  REWARD="${ADMOB_REWARD_ID:-}"
  if [ -z "$APP" ] || [ -z "$BANNER" ] || [ -z "$REWARD" ]; then
    erro "Para anúncios REAIS, cadastre os 3 segredos do AdMob: ADMOB_APP_ID, ADMOB_BANNER_ID e ADMOB_REWARD_ID."
  fi
  [[ "$APP" =~ ^ca-app-pub-[0-9]{12,20}~[0-9]{8,12}$ ]] \
    || erro "O ADMOB_APP_ID parece errado. O ID do APP tem um ~ (til) no meio, assim: ca-app-pub-1234567890123456~1234567890"
  [[ "$BANNER" =~ ^ca-app-pub-[0-9]{12,20}/[0-9]{8,12}$ ]] \
    || erro "O ADMOB_BANNER_ID parece errado. O ID de um bloco tem uma / (barra) no meio. Será que você colou o ID do app no lugar?"
  [[ "$REWARD" =~ ^ca-app-pub-[0-9]{12,20}/[0-9]{8,12}$ ]] \
    || erro "O ADMOB_REWARD_ID parece errado. O ID de um bloco tem uma / (barra) no meio."
  if [ "${APP%%~*}" != "${BANNER%%/*}" ] || [ "${APP%%~*}" != "${REWARD%%/*}" ]; then
    erro "Os 3 IDs do AdMob precisam ser da mesma conta (o começo ca-app-pub-… tem que ser igual nos três)."
  fi
  [ "$BANNER" != "$REWARD" ] \
    || erro "O ID do banner e o do vídeo premiado estão iguais. Crie dois blocos diferentes no AdMob."
  if [ "${APP%%~*}" = "${ADMOB_TEST_APP_ID%%~*}" ]; then
    erro "Os IDs do AdMob são os de TESTE do Google. Para anúncios reais, use os IDs do app BOSYN no AdMob."
  fi
  # A política vai dentro do app (asset): a versão de produção não pode levar campo em branco.
  if grep -q '\[PREENCHER' "$POLITICA"; then
    erro "A política de privacidade ($POLITICA) ainda tem [PREENCHER]. Ela aparece dentro do app: preencha antes de gerar a versão de produção."
  fi
  MODO=REAIS
  APP_ID="$APP"
else
  MODO=TESTE
  APP_ID="$ADMOB_TEST_APP_ID"
  if grep -q '\[PREENCHER' "$POLITICA"; then
    aviso "A política de privacidade ainda tem [PREENCHER]: serve para teste interno, mas preencha antes da produção."
  fi
fi

umask 077
{
  echo "SUPABASE_URL=$URL"
  echo "SUPABASE_PUBLISHABLE_KEY=$KEY"
  if [ "$MODO" = "REAIS" ]; then
    echo "ADMOB_APP_ID=$APP"
    echo "ADMOB_BANNER_ID=$BANNER"
    echo "ADMOB_REWARD_ID=$REWARD"
  fi
} > .env

saida modo "$MODO"
saida admob_app_id "$APP_ID"
echo "Configuração pronta: anúncios $MODO."
