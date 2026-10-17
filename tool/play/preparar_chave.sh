#!/usr/bin/env bash
# Prepara a assinatura do AAB: confere o keystore de upload e escreve android/key.properties
# (lido por android/app/build.gradle.kts; gitignored em android/.gitignore).
# Usado pelo botão "2 - Gerar AAB" (.github/workflows/2-gerar-aab.yml) e pelo ensaio do CI
# (job release-check) — a mesma preparação nos dois lugares.
#
# Uso (na raiz do repositório): tool/play/preparar_chave.sh <arquivo .jks> <senha>
# Opcional: KEY_ALIAS (quando o keystore tem mais de uma chave) e KEY_PASSWORD (chave JKS antiga
# com senha própria; no padrão PKCS12 a senha da chave é a do keystore).
set -euo pipefail

KEYSTORE="${1:?uso: tool/play/preparar_chave.sh <arquivo .jks> <senha>}"
PASSWORD="${2:?uso: tool/play/preparar_chave.sh <arquivo .jks> <senha>}"

erro() {
  echo "::error::$1"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "❌ $1" >> "$GITHUB_STEP_SUMMARY"; fi
  exit 1
}

# Saída do keytool sempre em inglês, para ler o nome (alias) da chave do mesmo jeito.
if ! LISTA=$(keytool -J-Duser.language=en -J-Duser.country=US -list \
  -keystore "$KEYSTORE" -storepass "$PASSWORD" 2>/dev/null); then
  erro "A chave (KEYSTORE_BASE64) e a senha (KEYSTORE_PASSWORD) não combinam. Confira se colou o texto inteiro do KEYSTORE_BASE64.txt e a senha certa."
fi

ALIAS="${KEY_ALIAS:-}"
if [ -z "$ALIAS" ]; then
  # Uma linha por chave: "upload, Oct 17, 2026, PrivateKeyEntry,"
  ALIASES=$(printf '%s\n' "$LISTA" | grep 'PrivateKeyEntry' | cut -d, -f1 || true)
  QUANTAS=$(printf '%s' "$ALIASES" | grep -c . || true)
  if [ "$QUANTAS" != "1" ]; then
    erro "O keystore tem $QUANTAS chaves. Deixe só a de upload ou crie a variável KEY_ALIAS (Settings → Secrets and variables → Actions → Variables) com o nome dela."
  fi
  ALIAS="$ALIASES"
fi

# java.util.Properties trata "\" como escape: dobra para a senha chegar inteira ao Gradle.
escapar() { printf '%s' "${1//\\/\\\\}"; }

mkdir -p android
umask 077
{
  echo "storeFile=$(escapar "$(cd "$(dirname "$KEYSTORE")" && pwd)/$(basename "$KEYSTORE")")"
  echo "storePassword=$(escapar "$PASSWORD")"
  echo "keyPassword=$(escapar "${KEY_PASSWORD:-$PASSWORD}")"
  echo "keyAlias=$(escapar "$ALIAS")"
} > android/key.properties

echo "Chave de upload pronta para assinar o AAB (alias: $ALIAS)."
