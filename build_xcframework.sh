#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="${ROOT_DIR}/Artifacts"
CURL_INCLUDE_DIR="${ROOT_DIR}/third_party/curl/include"
OPENSSL_XCFRAMEWORK="${1:-${ROOT_DIR}/../a-Shell/xcfs/.build/artifacts/xcfs/openssl/openssl.xcframework}"
CURL_XCFRAMEWORK="${2:-${ROOT_DIR}/../a-Shell/xcfs/.build/artifacts/xcfs/curl_ios/curl_ios.xcframework}"
LIBSSH2_XCFRAMEWORK="${3:-${ROOT_DIR}/../a-Shell/xcfs/.build/artifacts/xcfs/libssh2/libssh2.xcframework}"

TMP_DIR="$(mktemp -d)"
trap 'trash --stopOnError "${TMP_DIR}" >/dev/null 2>&1 || true' EXIT

if [ ! -d "${OPENSSL_XCFRAMEWORK}" ]; then
  echo "openssl xcframework not found: ${OPENSSL_XCFRAMEWORK}" >&2
  exit 1
fi

if [ ! -d "${CURL_XCFRAMEWORK}" ]; then
  echo "curl_ios xcframework not found: ${CURL_XCFRAMEWORK}" >&2
  exit 1
fi

if [ ! -d "${LIBSSH2_XCFRAMEWORK}" ]; then
  echo "libssh2 xcframework not found: ${LIBSSH2_XCFRAMEWORK}" >&2
  exit 1
fi

if [ ! -d "${CURL_INCLUDE_DIR}/curl" ]; then
  echo "curl headers not found: ${CURL_INCLUDE_DIR}/curl" >&2
  exit 1
fi

create_info_plist() {
  local output="$1"
  local bundle_id="$2"
  local executable="$3"
  /usr/bin/plutil -create xml1 "${output}"
  /usr/bin/plutil -insert CFBundleIdentifier -string "${bundle_id}" "${output}"
  /usr/bin/plutil -insert CFBundleName -string "${executable}" "${output}"
  /usr/bin/plutil -insert CFBundlePackageType -string "FMWK" "${output}"
  /usr/bin/plutil -insert CFBundleExecutable -string "${executable}" "${output}"
}

pick_slice_dir() {
  local xcframework="$1"
  local preferred="$2"
  local fallback="$3"

  if [ -d "${xcframework}/${preferred}" ]; then
    printf '%s\n' "${xcframework}/${preferred}"
    return
  fi

  if [ -n "${fallback}" ] && [ -d "${xcframework}/${fallback}" ]; then
    printf '%s\n' "${xcframework}/${fallback}"
    return
  fi

  echo "missing slice in ${xcframework}: ${preferred}${fallback:+ or ${fallback}}" >&2
  exit 1
}

dump_make_var() {
  local dump="$1"
  local name="$2"
  printf '%s\n' "${dump}" | sed -n "s/^${name} =  //p" | head -n 1
}

build_slice() {
  local sdk="$1"
  local arch="$2"
  local openssl_dir="$3"
  local curl_dir="$4"
  local libssh2_dir="$5"
  local min_flag="$6"
  local tag="$7"

  local include_dir="${TMP_DIR}/include-${tag}"
  local out_dir="${TMP_DIR}/${tag}"
  mkdir -p "${include_dir}" "${out_dir}/git.framework" "${out_dir}/gitremote.framework"
  ln -s "${openssl_dir}/openssl.framework/Headers" "${include_dir}/openssl"

  local developer_cflags="-I${include_dir} -I${CURL_INCLUDE_DIR} -DGIT_IOS_EMBED=1"
  local openssl_link="-F${openssl_dir} -framework openssl"
  local curl_link="-F${curl_dir} -framework curl_ios"
  local libssh2_link="-F${libssh2_dir} -framework libssh2"

  local -a make_vars=(
    "CC=xcrun --sdk ${sdk} clang -arch ${arch} ${min_flag}"
    "AR=xcrun ar"
    "RANLIB=xcrun ranlib"
    "DEVELOPER_CFLAGS=${developer_cflags}"
    "OPENSSL_LIBSSL=${openssl_link}"
    "LIB_4_CRYPTO="
    "CURL_CFLAGS=-I${CURL_INCLUDE_DIR}"
    "CURL_LDFLAGS=${curl_link} ${openssl_link} ${libssh2_link}"
    "NO_PERL=YesPlease"
    "NO_TCLTK=YesPlease"
    "NO_GETTEXT=YesPlease"
    "NO_PYTHON=YesPlease"
    "NO_EXPAT=YesPlease"
    "NO_APPLE_COMMON_CRYPTO=YesPlease"
    "FSMONITOR_DAEMON_BACKEND="
    "FSMONITOR_OS_SETTINGS="
    "USE_LIBPCRE2="
  )

  local make_dump
  make_dump="$(
    cd "${ROOT_DIR}"
    make -pn "${make_vars[@]}"
  )"

  local lib_objs
  local builtin_objs
  local compat_objs
  lib_objs="$(dump_make_var "${make_dump}" "LIB_OBJS" | sed 's/ $(COMPAT_OBJS)//g')"
  builtin_objs="$(dump_make_var "${make_dump}" "BUILTIN_OBJS")"
  compat_objs="$(dump_make_var "${make_dump}" "COMPAT_OBJS")"
  local -a build_targets
  read -r -a build_targets <<< "${lib_objs} ${builtin_objs} ${compat_objs}"
  build_targets+=(git.o remote-curl.o http.o http-walker.o)

  (
    cd "${ROOT_DIR}"
    make clean >/dev/null 2>&1 || true
    make -j4 "${make_vars[@]}" "${build_targets[@]}"
    eval xcrun --sdk "${sdk}" clang -arch "${arch}" ${min_flag} ${developer_cflags} -c git-ios-exit.c -o git-ios-exit.o
    eval xcrun --sdk "${sdk}" clang -arch "${arch}" ${min_flag} ${developer_cflags} -c git-wrapper.c -o git-wrapper.o
    eval xcrun --sdk "${sdk}" clang -arch "${arch}" ${min_flag} ${developer_cflags} -c git-remote-http-wrapper.c -o git-remote-http-wrapper.o
  )

  create_info_plist "${out_dir}/git.framework/Info.plist" "com.zats.git-ios.git" "git"
  create_info_plist "${out_dir}/gitremote.framework/Info.plist" "com.zats.git-ios.gitremote" "gitremote"

  (
    cd "${ROOT_DIR}"
    eval xcrun --sdk "${sdk}" clang -arch "${arch}" ${min_flag} -dynamiclib \
      ${lib_objs} ${builtin_objs} ${compat_objs} git-ios-exit.o git-wrapper.o git.o \
      -F "${openssl_dir}" -framework openssl -lz -liconv \
      -o "${out_dir}/git.framework/git" \
      -install_name @rpath/git.framework/git

    eval xcrun --sdk "${sdk}" clang -arch "${arch}" ${min_flag} -dynamiclib \
      remote-curl.o http.o http-walker.o git-ios-exit.o git-remote-http-wrapper.o \
      -F "${out_dir}" \
      -F "${out_dir}" -framework git \
      -F "${curl_dir}" -framework curl_ios \
      -F "${openssl_dir}" -framework openssl \
      -F "${libssh2_dir}" -framework libssh2 \
      -lz -liconv \
      -o "${out_dir}/gitremote.framework/gitremote" \
      -install_name @rpath/gitremote.framework/gitremote
  )
}

IOS_OPENSSL_DIR="$(pick_slice_dir "${OPENSSL_XCFRAMEWORK}" "ios-arm64" "ios-arm64_arm64e")"
IOS_CURL_DIR="$(pick_slice_dir "${CURL_XCFRAMEWORK}" "ios-arm64" "")"
IOS_LIBSSH2_DIR="$(pick_slice_dir "${LIBSSH2_XCFRAMEWORK}" "ios-arm64" "ios-arm64_arm64e")"
SIM_OPENSSL_DIR="$(pick_slice_dir "${OPENSSL_XCFRAMEWORK}" "ios-arm64_x86_64-simulator" "")"
SIM_CURL_DIR="$(pick_slice_dir "${CURL_XCFRAMEWORK}" "ios-arm64_x86_64-simulator" "")"
SIM_LIBSSH2_DIR="$(pick_slice_dir "${LIBSSH2_XCFRAMEWORK}" "ios-arm64_x86_64-simulator" "")"

build_slice iphoneos arm64 \
  "${IOS_OPENSSL_DIR}" \
  "${IOS_CURL_DIR}" \
  "${IOS_LIBSSH2_DIR}" \
  "-miphoneos-version-min=17.0" \
  "ios-arm64"

build_slice iphonesimulator arm64 \
  "${SIM_OPENSSL_DIR}" \
  "${SIM_CURL_DIR}" \
  "${SIM_LIBSSH2_DIR}" \
  "-mios-simulator-version-min=17.0" \
  "sim-arm64"

build_slice iphonesimulator x86_64 \
  "${SIM_OPENSSL_DIR}" \
  "${SIM_CURL_DIR}" \
  "${SIM_LIBSSH2_DIR}" \
  "-mios-simulator-version-min=17.0" \
  "sim-x86_64"

mkdir -p "${TMP_DIR}/sim-merged/git.framework" "${TMP_DIR}/sim-merged/gitremote.framework"
cp "${TMP_DIR}/sim-arm64/git.framework/Info.plist" "${TMP_DIR}/sim-merged/git.framework/Info.plist"
cp "${TMP_DIR}/sim-arm64/gitremote.framework/Info.plist" "${TMP_DIR}/sim-merged/gitremote.framework/Info.plist"

lipo -create \
  "${TMP_DIR}/sim-arm64/git.framework/git" \
  "${TMP_DIR}/sim-x86_64/git.framework/git" \
  -output "${TMP_DIR}/sim-merged/git.framework/git"

lipo -create \
  "${TMP_DIR}/sim-arm64/gitremote.framework/gitremote" \
  "${TMP_DIR}/sim-x86_64/gitremote.framework/gitremote" \
  -output "${TMP_DIR}/sim-merged/gitremote.framework/gitremote"

mkdir -p "${ARTIFACTS_DIR}"
if [ -e "${ARTIFACTS_DIR}/git.xcframework" ]; then
  trash --stopOnError "${ARTIFACTS_DIR}/git.xcframework"
fi
if [ -e "${ARTIFACTS_DIR}/gitremote.xcframework" ]; then
  trash --stopOnError "${ARTIFACTS_DIR}/gitremote.xcframework"
fi

xcodebuild -create-xcframework \
  -framework "${TMP_DIR}/ios-arm64/git.framework" \
  -framework "${TMP_DIR}/sim-merged/git.framework" \
  -output "${ARTIFACTS_DIR}/git.xcframework"

xcodebuild -create-xcframework \
  -framework "${TMP_DIR}/ios-arm64/gitremote.framework" \
  -framework "${TMP_DIR}/sim-merged/gitremote.framework" \
  -output "${ARTIFACTS_DIR}/gitremote.xcframework"

otool -L "${ARTIFACTS_DIR}/git.xcframework/ios-arm64/git.framework/git"
otool -L "${ARTIFACTS_DIR}/gitremote.xcframework/ios-arm64/gitremote.framework/gitremote"
du -sh "${ARTIFACTS_DIR}/git.xcframework" "${ARTIFACTS_DIR}/gitremote.xcframework"
