#!/usr/bin/env bash
# Confere o AAB antes de ele ir para a Play:
#   1. assinado (e com a chave de upload, nunca a debug, que a Play Console recusa);
#   2. ID do app no AdMob esperado no manifesto (sem ID válido o SDK fecha o app ao abrir) e a
#      permissão de compra (BILLING) presente;
#   3. bibliotecas nativas 64-bit alinhadas a 16 KB (tool/check_elf_alignment.dart).
# Usado pelo botão "2 - Gerar AAB" e pelo ensaio do CI (job release-check).
#
# Uso (na raiz do repositório): tool/play/conferir_aab.sh <app.aab> <ID do app no AdMob>
# Escreve as impressões digitais da chave em $GITHUB_STEP_SUMMARY quando existe.
set -euo pipefail

AAB="${1:?uso: tool/play/conferir_aab.sh <app.aab> <ID do app no AdMob>}"
ADMOB_APP_ID="${2:?uso: tool/play/conferir_aab.sh <app.aab> <ID do app no AdMob>}"

erro() {
  echo "::error::$1"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "❌ $1" >> "$GITHUB_STEP_SUMMARY"; fi
  exit 1
}

[ -f "$AAB" ] || erro "AAB não encontrado: $AAB"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. Assinatura
jarsigner -verify "$AAB" > "$TMP/verify.txt" 2>&1 || erro "O AAB não está assinado (jarsigner -verify falhou)."
grep -q "jar verified" "$TMP/verify.txt" || erro "O AAB não está assinado (jarsigner -verify não confirmou)."
CERT=$(keytool -J-Duser.language=en -J-Duser.country=US -printcert -jarfile "$AAB")
if printf '%s\n' "$CERT" | grep -q "CN=Android Debug"; then
  erro "O AAB foi assinado com a chave DEBUG: a Play Console recusa. Confira os segredos KEYSTORE_*."
fi
SHA1=$(printf '%s\n' "$CERT" | sed -n 's/^[[:space:]]*SHA1: //p' | head -1)
SHA256=$(printf '%s\n' "$CERT" | sed -n 's/^[[:space:]]*SHA256: //p' | head -1)

# 2. Manifesto (formato protobuf dentro do AAB: os textos aparecem como estão)
unzip -p "$AAB" base/manifest/AndroidManifest.xml > "$TMP/manifest.pb" 2>/dev/null \
  || erro "O AAB não tem base/manifest/AndroidManifest.xml."
grep -aqF "$ADMOB_APP_ID" "$TMP/manifest.pb" \
  || erro "O manifesto do AAB não tem o ID do app no AdMob esperado ($ADMOB_APP_ID)."
grep -aqF "com.android.vending.BILLING" "$TMP/manifest.pb" \
  || erro "O manifesto do AAB não tem a permissão de compra (com.android.vending.BILLING)."

# 3. Páginas de 16 KB
unzip -q -o "$AAB" 'base/lib/*' -d "$TMP/libs" 2>/dev/null || erro "O AAB não tem bibliotecas nativas (base/lib)."
dart tool/check_elf_alignment.dart "$TMP/libs" \
  || erro "Alguma biblioteca nativa do AAB não está alinhada a 16 KB (exigência da Play)."

echo "AAB conferido: assinatura de upload, AdMob ($ADMOB_APP_ID), compra e 16 KB."
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "🔏 Chave de upload — SHA-1: \`$SHA1\`"
    echo ""
    echo "🔏 Chave de upload — SHA-256: \`$SHA256\`"
    echo ""
  } >> "$GITHUB_STEP_SUMMARY"
fi
