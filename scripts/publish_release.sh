#!/usr/bin/env bash
#
# Publish a Veda release from the build host (titan-gpu).
#
# Usage:
#   scripts/publish_release.sh v6.0.0-rc1 [--artifacts-dir ./dist] [--prerelease]
#
# Preconditions:
#   - All artifacts already built and placed in --artifacts-dir
#   - minisign private key at ~/.minisign/veda-release.key (mode 600)
#   - gh CLI authenticated with rights on rishav1305/veda-releases
#
# This script:
#   1. Signs every artifact with minisign
#   2. Generates and signs SHA256SUMS
#   3. Creates the GitHub Release and uploads everything
#
# It never re-uses an existing release and bails on the first failure.

set -euo pipefail

REPO="rishav1305/veda-releases"
KEY_PATH="${HOME}/.minisign/veda-release.key"

VERSION=""
ARTIFACTS_DIR="./dist"
PRERELEASE_FLAG=""

err() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat >&2 <<EOF
Usage: $0 VERSION [--artifacts-dir PATH] [--prerelease]

  VERSION              Tag to publish (e.g. v6.0.0-rc1). Must already be pushed.
  --artifacts-dir PATH Directory containing build outputs (default: ./dist)
  --prerelease         Mark the GitHub Release as a prerelease
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --artifacts-dir)
      [ $# -ge 2 ] || err "--artifacts-dir requires a value"
      ARTIFACTS_DIR="$2"
      shift 2
      ;;
    --prerelease)
      PRERELEASE_FLAG="--prerelease"
      shift
      ;;
    -*)
      err "unknown flag: $1"
      ;;
    *)
      if [ -z "${VERSION}" ]; then
        VERSION="$1"
        shift
      else
        err "unexpected positional argument: $1"
      fi
      ;;
  esac
done

[ -n "${VERSION}" ] || usage

case "${VERSION}" in
  v*) ;;
  *) err "VERSION must start with 'v' (got: ${VERSION})" ;;
esac

command -v minisign >/dev/null 2>&1 || err "minisign not installed"
command -v gh       >/dev/null 2>&1 || err "gh CLI not installed"

if [ ! -f "${KEY_PATH}" ]; then
  cat >&2 <<EOF
error: minisign private key not found at ${KEY_PATH}

Retrieve it from Vaultwarden:
  mkdir -p ~/.minisign
  bw get item veda-release-minisign-key | jq -r .notes > ${KEY_PATH}
  chmod 600 ${KEY_PATH}

Then rerun this script.
EOF
  exit 1
fi

key_mode=$(stat -c '%a' "${KEY_PATH}" 2>/dev/null || stat -f '%A' "${KEY_PATH}")
if [ "${key_mode}" != "600" ]; then
  err "${KEY_PATH} mode is ${key_mode}; expected 600. Run: chmod 600 ${KEY_PATH}"
fi

[ -d "${ARTIFACTS_DIR}" ] || err "artifacts dir not found: ${ARTIFACTS_DIR}"

shopt -s nullglob
mapfile -t ARTIFACTS < <(find "${ARTIFACTS_DIR}" -maxdepth 1 -type f \
  ! -name '*.minisig' ! -name 'SHA256SUMS' ! -name 'SHA256SUMS.minisig' \
  -printf '%f\n' | sort)
shopt -u nullglob

[ "${#ARTIFACTS[@]}" -gt 0 ] || err "no artifacts to publish in ${ARTIFACTS_DIR}"

cd "${ARTIFACTS_DIR}"

printf 'publishing %d artifact(s) for %s:\n' "${#ARTIFACTS[@]}" "${VERSION}"
for f in "${ARTIFACTS[@]}"; do
  printf '  - %s\n' "${f}"
done

printf 'signing artifacts\n'
for f in "${ARTIFACTS[@]}"; do
  rm -f "${f}.minisig"
  if ! minisign -Sm "${f}" -s "${KEY_PATH}"; then
    err "minisign failed on ${f}"
  fi
done

printf 'generating SHA256SUMS\n'
rm -f SHA256SUMS SHA256SUMS.minisig
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${ARTIFACTS[@]}" > SHA256SUMS
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${ARTIFACTS[@]}" > SHA256SUMS
else
  err "neither sha256sum nor shasum is available"
fi

printf 'signing SHA256SUMS\n'
if ! minisign -Sm SHA256SUMS -s "${KEY_PATH}"; then
  err "minisign failed on SHA256SUMS"
fi

UPLOADS=()
for f in "${ARTIFACTS[@]}"; do
  UPLOADS+=("${f}" "${f}.minisig")
done
UPLOADS+=("SHA256SUMS" "SHA256SUMS.minisig")

printf 'creating GitHub Release %s on %s\n' "${VERSION}" "${REPO}"
if ! gh release create "${VERSION}" "${UPLOADS[@]}" \
      --repo "${REPO}" \
      --notes-from-tag \
      ${PRERELEASE_FLAG}; then
  err "gh release create failed"
fi

printf 'released: https://github.com/%s/releases/tag/%s\n' "${REPO}" "${VERSION}"
