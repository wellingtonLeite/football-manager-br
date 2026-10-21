#!/usr/bin/env bash
# Passos do build do APK. Este arquivo fica fora de .github/ de propósito:
# o upload pelo site do GitHub ignora pastas que começam com ponto, então
# toda a lógica do build mora aqui e pode ser atualizada por upload.
#
# Uso: bash ci/build.sh build   -> dependências, análise e APK
#      bash ci/build.sh test    -> testes automatizados
set -euo pipefail
cd "$(dirname "$0")/.."

phase="${1:-build}"

prepare() {
  flutter --version
  java -version 2>&1 | head -1
  # Gerado na máquina de quem rodou o Flutter, com caminhos locais: nunca vale no CI
  rm -f android/local.properties
  if [ ! -d android ]; then
    echo "Pasta android/ ausente: gerando com flutter create"
    flutter create --platforms=android --org br.com.fmbr --project-name football_manager_br .
    rm -f test/widget_test.dart
  fi
  flutter pub get
  setup_signing
}

# Chave fixa de assinatura vinda dos segredos do GitHub (Settings › Secrets › Actions).
setup_signing() {
  if [ -n "${ANDROID_KEYSTORE_BASE64:-}" ] && [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
    echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
    cat > android/key.properties <<PROPS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
PROPS
    echo "APK será assinado com a chave fixa do projeto."
  else
    echo "AVISO: segredos ANDROID_KEYSTORE_* não configurados; usando chave de depuração."
  fi
}

case "$phase" in
  build)
    prepare
    flutter analyze --no-fatal-infos --no-fatal-warnings
    flutter build apk --release
    ls -la build/app/outputs/flutter-apk/
    ;;
  test)
    flutter test
    ;;
  *)
    echo "Fase desconhecida: $phase (use build ou test)" >&2
    exit 2
    ;;
esac
