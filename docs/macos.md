# macOS install

Veda for macOS ships as a `.dmg` containing `Veda.app`. The installer downloads
and verifies the disk image, then opens it for you. The actual drag-to-Applications
step is manual on purpose so you can decide where the app lives.

## Quick install

```bash
curl -fsSL https://rishavchatterjee.com/veda/install.sh | bash
```

The script:

1. Detects macOS + your arch (`x86_64` or `arm64`).
2. Downloads `veda-desktop-macos-<arch>-<version>.dmg`, its `.minisig`, the
   signed `SHA256SUMS`, and the release public key.
3. Verifies both signatures with `minisign` and the SHA256 hash.
4. Opens the disk image. Drag **Veda** into **Applications**.

## Gatekeeper

Veda is not yet notarized by Apple. On first launch you may see:

> "Veda" cannot be opened because the developer cannot be verified.

Remove the quarantine attribute once after install:

```bash
xattr -d com.apple.quarantine /Applications/Veda.app
```

Then double-click `Veda.app` again. macOS will remember the decision.

> TODO: code-sign and notarize the macOS build so Gatekeeper accepts it without
> the `xattr` workaround. Tracked alongside the V8.x release-engineering work.

## Uninstall

```bash
rm -rf /Applications/Veda.app
rm -rf "${HOME}/Library/Application Support/Veda"
rm -rf "${HOME}/Library/Preferences/com.rishavchatterjee.veda.plist"
```

## Required tooling

- `minisign` — `brew install minisign`
- `curl` — bundled with macOS
- `tar`, `awk`, `grep` — bundled with macOS

Apple Silicon and Intel Macs are both supported; the installer picks the right
artifact based on `uname -m`.
