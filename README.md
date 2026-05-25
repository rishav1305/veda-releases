# veda-releases

Public release artifacts for [Veda](https://rishavchatterjee.com/veda), a mobile-first
AI assistant. The Veda source code is private and lives on a self-hosted Gitea instance;
this repository exists only to distribute signed binaries. Every Git tag here corresponds
to a [GitHub Release](https://github.com/rishav1305/veda-releases/releases) that attaches
the platform artifacts plus their `.minisig` signatures and a signed `SHA256SUMS` file.

There is intentionally no source code in this repository.

## Install

One-liner (recommended):

```bash
curl -fsSL https://rishavchatterjee.com/veda/install.sh | bash
```

Direct fallback (no DNS dependency on the apex domain):

```bash
curl -fsSL https://raw.githubusercontent.com/rishav1305/veda-releases/main/install.sh | bash
```

Pin a specific release or pick a component:

```bash
VEDA_VERSION=v6.0.0-rc1 VEDA_COMPONENT=desktop bash install.sh
VEDA_COMPONENT=server                         bash install.sh
```

| `VEDA_COMPONENT` | What it installs                                  |
| ---------------- | ------------------------------------------------- |
| `desktop`        | Veda app for the current OS (Linux / macOS)       |
| `server`         | FastAPI router for self-hosting (Linux only)      |

Android is browser-only: visit <https://rishavchatterjee.com/veda> on your phone
and tap the APK link. The shell installer will detect Android and tell you the same.

## Verify manually

The installer verifies every artifact with [minisign](https://jedisct1.github.io/minisign/)
and rejects unsigned downloads. To verify by hand:

```bash
TAG=v6.0.0-rc1
FILE=veda-desktop-linux-x86_64-${TAG}.tar.gz
BASE=https://github.com/rishav1305/veda-releases/releases/download/${TAG}

curl -fLO ${BASE}/${FILE}
curl -fLO ${BASE}/${FILE}.minisig
curl -fLO ${BASE}/SHA256SUMS
curl -fLO ${BASE}/SHA256SUMS.minisig
curl -fLO https://raw.githubusercontent.com/rishav1305/veda-releases/main/keys/veda-release.pub

minisign -Vm ${FILE}      -p veda-release.pub
minisign -Vm SHA256SUMS   -p veda-release.pub
sha256sum -c SHA256SUMS --ignore-missing
```

## Per-platform docs

- [Linux desktop](docs/linux.md)
- [macOS desktop](docs/macos.md)
- [Android](docs/android.md)
- [Self-hosted server](docs/server.md)

## Why no CI?

Releases are built and signed on a known-good build host (titan-gpu) and pushed
with `scripts/publish_release.sh`. There is no GitHub Actions workflow on purpose:
the signing key never leaves the build host, and the public repo never sees source.
