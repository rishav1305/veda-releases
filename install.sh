#!/usr/bin/env bash
#
# Veda installer
#
#   curl -fsSL https://rishavchatterjee.com/veda/install.sh | bash
#
# Environment:
#   VEDA_VERSION    Tag to install (default: latest). Examples: v6.0.0-rc1
#   VEDA_COMPONENT  desktop | server (default: desktop)
#
# Signature verification with minisign is mandatory. There is no skip flag.

set -euo pipefail

REPO="rishav1305/veda-releases"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
RELEASE_LATEST="https://github.com/${REPO}/releases/latest/download"
RELEASE_TAG_BASE="https://github.com/${REPO}/releases/download"

VEDA_VERSION="${VEDA_VERSION:-latest}"
VEDA_COMPONENT="${VEDA_COMPONENT:-desktop}"

TMPDIR=""

cleanup() {
  local code=$?
  if [ -n "${TMPDIR}" ] && [ -d "${TMPDIR}" ]; then
    rm -rf "${TMPDIR}"
  fi
  exit "${code}"
}
trap cleanup EXIT INT TERM

err() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "required command not found: $1"
}

minisign_install_hint() {
  case "$1" in
    macos)
      cat >&2 <<'EOF'
minisign is required to verify release signatures.
Install on macOS:
  brew install minisign
EOF
      ;;
    linux)
      cat >&2 <<'EOF'
minisign is required to verify release signatures.
Install on Debian/Ubuntu:
  sudo apt install minisign
Install on Arch:
  sudo pacman -S minisign
Install on Fedora:
  sudo dnf install minisign
EOF
      ;;
  esac
}

detect_platform() {
  local uname_s uname_m uname_o os arch
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  uname_m="$(uname -m 2>/dev/null || echo unknown)"
  uname_o="$(uname -o 2>/dev/null || echo unknown)"

  if printf '%s' "${uname_o}" | grep -qi 'android'; then
    cat >&2 <<'EOF'
Veda for Android is installed via your browser, not this script.
Open this page on your phone:
  https://rishavchatterjee.com/veda
and tap the Android download link.
EOF
    exit 1
  fi

  case "${uname_s}" in
    Linux)  os="linux"  ;;
    Darwin) os="macos"  ;;
    *)
      err "unsupported OS: ${uname_s}. See https://rishavchatterjee.com/veda"
      ;;
  esac

  case "${uname_m}" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
      err "unsupported architecture: ${uname_m}. See https://rishavchatterjee.com/veda"
      ;;
  esac

  PLATFORM_OS="${os}"
  PLATFORM_ARCH="${arch}"
}

artifact_name() {
  local component="$1" os="$2" arch="$3" version="$4"
  if [ "${os}" = "macos" ] && [ "${component}" = "desktop" ]; then
    printf 'veda-desktop-macos-%s-%s.dmg' "${arch}" "${version}"
    return
  fi
  printf 'veda-%s-%s-%s-%s.tar.gz' "${component}" "${os}" "${arch}" "${version}"
}

release_url() {
  local file="$1"
  if [ "${VEDA_VERSION}" = "latest" ]; then
    printf '%s/%s' "${RELEASE_LATEST}" "${file}"
  else
    printf '%s/%s/%s' "${RELEASE_TAG_BASE}" "${VEDA_VERSION}" "${file}"
  fi
}

fetch() {
  local url="$1" out="$2"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "${out}" "${url}"; then
    err "download failed: ${url}"
  fi
}

verify_sha256() {
  local file="$1" sumsfile="$2"
  local base
  base="$(basename "${file}")"
  local expected
  expected="$(grep -E "[[:space:]]${base}\$" "${sumsfile}" | awk '{print $1}' | head -n1)"
  if [ -z "${expected}" ]; then
    err "no SHA256 entry for ${base} in SHA256SUMS"
  fi
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${file}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${file}" | awk '{print $1}')"
  else
    err "neither sha256sum nor shasum is available"
  fi
  if [ "${expected}" != "${actual}" ]; then
    err "SHA256 mismatch for ${base}: expected ${expected}, got ${actual}"
  fi
  info "sha256 ok: ${base}"
}

install_linux_tarball() {
  local file="$1" target="$2"
  mkdir -p "${target}"
  if ! tar -xzf "${file}" -C "${target}"; then
    err "failed to extract ${file} into ${target}"
  fi
  info "extracted to ${target}"
}

install_macos_dmg() {
  local file="$1"
  info "opening ${file} — drag Veda.app to /Applications"
  if ! open "${file}"; then
    err "failed to open ${file}"
  fi
  cat <<'EOF'

If Gatekeeper blocks the app on first launch, remove the quarantine flag:
  xattr -d com.apple.quarantine /Applications/Veda.app

EOF
}

main() {
  case "${VEDA_COMPONENT}" in
    desktop|server) ;;
    *) err "VEDA_COMPONENT must be 'desktop' or 'server' (got: ${VEDA_COMPONENT})" ;;
  esac

  require_cmd curl
  require_cmd uname
  require_cmd tar
  require_cmd awk
  require_cmd grep

  detect_platform

  if ! command -v minisign >/dev/null 2>&1; then
    minisign_install_hint "${PLATFORM_OS}"
    err "minisign is required"
  fi

  if [ "${VEDA_COMPONENT}" = "server" ] && [ "${PLATFORM_OS}" = "macos" ]; then
    err "server component on macOS is not packaged yet; use Linux for self-hosting"
  fi

  local file url
  file="$(artifact_name "${VEDA_COMPONENT}" "${PLATFORM_OS}" "${PLATFORM_ARCH}" "${VEDA_VERSION}")"
  url="$(release_url "${file}")"

  TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/veda-install.XXXXXXXX")"

  info "veda-releases: ${REPO}"
  info "version:       ${VEDA_VERSION}"
  info "component:     ${VEDA_COMPONENT}"
  info "platform:      ${PLATFORM_OS}/${PLATFORM_ARCH}"
  info "artifact:      ${file}"

  fetch "${url}"                "${TMPDIR}/${file}"
  fetch "${url}.minisig"        "${TMPDIR}/${file}.minisig"
  fetch "$(release_url SHA256SUMS)"          "${TMPDIR}/SHA256SUMS"
  fetch "$(release_url SHA256SUMS.minisig)"  "${TMPDIR}/SHA256SUMS.minisig"
  fetch "${RAW_BASE}/keys/veda-release.pub"  "${TMPDIR}/veda-release.pub"

  if grep -q '^# PLACEHOLDER' "${TMPDIR}/veda-release.pub"; then
    err "release public key is still a placeholder. Refusing to install unsigned artifacts."
  fi

  info "verifying signature on artifact"
  if ! minisign -Vm "${TMPDIR}/${file}" -p "${TMPDIR}/veda-release.pub"; then
    err "minisign verification failed for ${file}"
  fi

  info "verifying signature on SHA256SUMS"
  if ! minisign -Vm "${TMPDIR}/SHA256SUMS" -p "${TMPDIR}/veda-release.pub"; then
    err "minisign verification failed for SHA256SUMS"
  fi

  verify_sha256 "${TMPDIR}/${file}" "${TMPDIR}/SHA256SUMS"

  case "${PLATFORM_OS}-${VEDA_COMPONENT}" in
    linux-desktop)
      install_linux_tarball "${TMPDIR}/${file}" "${HOME}/.local/veda"
      cat <<EOF

Installed to ${HOME}/.local/veda

Add to PATH (bash or zsh):
  export PATH="\$HOME/.local/veda/bin:\$PATH"

See https://github.com/${REPO}/blob/main/docs/linux.md for a .desktop entry.
EOF
      ;;
    linux-server)
      install_linux_tarball "${TMPDIR}/${file}" "${HOME}/.local/veda-server"
      cat <<EOF

Installed to ${HOME}/.local/veda-server

Config lives at ~/.veda/ (created on first run).
Start the router:
  ${HOME}/.local/veda-server/bin/veda-router serve

systemd unit example and full notes:
  https://github.com/${REPO}/blob/main/docs/server.md
EOF
      ;;
    macos-desktop)
      install_macos_dmg "${TMPDIR}/${file}"
      ;;
    *)
      err "no installer path for ${PLATFORM_OS}-${VEDA_COMPONENT}"
      ;;
  esac

  info "done"
}

main "$@"
