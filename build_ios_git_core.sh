#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/Artifacts"
OPENSSL_FRAMEWORK_DIR_DEFAULT="${ROOT_DIR}/../a-Shell/xcfs/.build/artifacts/xcfs/openssl/openssl.xcframework/ios-arm64/openssl.framework"
OPENSSL_FRAMEWORK_DIR="${1:-$OPENSSL_FRAMEWORK_DIR_DEFAULT}"

if [ ! -d "${OPENSSL_FRAMEWORK_DIR}" ]; then
  echo "openssl framework not found: ${OPENSSL_FRAMEWORK_DIR}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'trash --stopOnError "${TMP_DIR}" >/dev/null 2>&1 || true' EXIT

mkdir -p "${TMP_DIR}/include"
ln -s "${OPENSSL_FRAMEWORK_DIR}/Headers" "${TMP_DIR}/include/openssl"

cd "${ROOT_DIR}"
make clean >/dev/null 2>&1 || true
make -j4 git \
  CC='xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=17.0' \
  AR='xcrun ar' \
  RANLIB='xcrun ranlib' \
  DEVELOPER_CFLAGS="-I${TMP_DIR}/include" \
  OPENSSL_LIBSSL="-F$(dirname "${OPENSSL_FRAMEWORK_DIR}") -framework openssl" \
  LIB_4_CRYPTO= \
  NO_PERL=YesPlease \
  NO_TCLTK=YesPlease \
  NO_GETTEXT=YesPlease \
  NO_PYTHON=YesPlease \
  NO_EXPAT=YesPlease \
  NO_CURL=YesPlease \
  NO_APPLE_COMMON_CRYPTO=YesPlease \
  FSMONITOR_DAEMON_BACKEND= \
  FSMONITOR_OS_SETTINGS= \
  USE_LIBPCRE2=

mkdir -p "${ARTIFACTS_DIR}"
cp git "${ARTIFACTS_DIR}/git-arm64"
file "${ARTIFACTS_DIR}/git-arm64"
du -sh "${ARTIFACTS_DIR}/git-arm64"
