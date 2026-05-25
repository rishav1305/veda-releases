# Linux desktop install

The installer drops a self-contained tree under `~/.local/veda/`. There is no
system-wide install path and no root required.

## Quick install

```bash
curl -fsSL https://rishavchatterjee.com/veda/install.sh | bash
```

This will:

1. Detect your distro's arch (`x86_64` or `arm64`).
2. Download `veda-desktop-linux-<arch>-<version>.tar.gz`, its `.minisig`, the
   signed `SHA256SUMS`, and the release public key.
3. Verify both signatures with `minisign` plus the SHA256 hash.
4. Extract into `~/.local/veda/`.

## Add to PATH

Append to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/veda/bin:$PATH"
```

Then `source ~/.bashrc` (or open a new terminal) and run:

```bash
veda --version
```

## Desktop entry

Create `~/.local/share/applications/veda.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Veda
Comment=Mobile-first AI assistant
Exec=%h/.local/veda/bin/veda
Icon=%h/.local/veda/share/icons/veda.png
Terminal=false
Categories=Utility;Network;AudioVideo;
StartupWMClass=veda
```

Then refresh your launcher's cache:

```bash
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
```

## Runtime dependencies

The tarball ships its own GLib, libsecret, sqlite, and FFmpeg shims, so a stock
Debian 12 / Ubuntu 22.04 / Arch / Fedora 39 system needs nothing extra. If a
shared library complains on launch, install the platform's `libsecret` and
`gtk3` packages — those are the only host requirements.

| Distro       | Package install                                |
| ------------ | ---------------------------------------------- |
| Debian/Ubuntu| `sudo apt install libsecret-1-0 libgtk-3-0`    |
| Arch         | `sudo pacman -S libsecret gtk3`                |
| Fedora       | `sudo dnf install libsecret gtk3`              |

## Uninstall

```bash
rm -rf ~/.local/veda
rm -f  ~/.local/share/applications/veda.desktop
rm -rf ~/.veda
```
