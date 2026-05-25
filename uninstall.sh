#!/usr/bin/env bash
#
# Veda uninstaller
#
# Examples:
#   curl -fsSL https://rishavchatterjee.com/veda/uninstall.sh | bash
#   curl -fsSL https://rishavchatterjee.com/veda/uninstall.sh | bash -s -- --purge-user-data
#
# Removes the installer-managed pieces:
#   - ~/.local/veda/                          (desktop client)
#   - ~/.local/veda-server/                   (server install + .venv)
#   - ~/.config/systemd/user/veda-router.service (+ enable symlink)
#   - ~/.local/share/applications/veda.desktop
#   - ~/Desktop/veda.desktop
#   - GNOME favorites pin
#
# Keeps ~/.veda/ (DBs, API keys, audit logs) unless --purge-user-data is passed.
# Does NOT touch any /opt or /etc paths (no sudo required).

set -euo pipefail

PURGE_DATA=0
for arg in "$@"; do
  case "$arg" in
    --purge-user-data) PURGE_DATA=1 ;;
    -h|--help)
      cat <<'USAGE'
Veda uninstaller

Usage:
  bash uninstall.sh                       (keeps ~/.veda/ user data)
  bash uninstall.sh --purge-user-data     (also deletes ~/.veda/)

Removes desktop client, server, systemd unit, launcher, desktop shortcut,
and GNOME taskbar pin.
USAGE
      exit 0 ;;
    *)
      printf 'unknown arg: %s\n' "$arg" >&2
      exit 1 ;;
  esac
done

step() { printf '\n[uninstall] %s\n' "$*"; }

# 1. Stop + disable + remove user-level systemd unit
if [ -f "$HOME/.config/systemd/user/veda-router.service" ]; then
  step "stopping + disabling veda-router.service (user)..."
  systemctl --user stop veda-router.service 2>/dev/null || true
  systemctl --user disable veda-router.service 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/veda-router.service"
  rm -f "$HOME/.config/systemd/user/default.target.wants/veda-router.service"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user reset-failed veda-router.service 2>/dev/null || true
else
  step "no user-level veda-router.service unit to remove"
fi

# 2. Install trees
if [ -d "$HOME/.local/veda" ]; then
  step "removing $HOME/.local/veda/ (desktop client)..."
  rm -rf "$HOME/.local/veda"
fi
if [ -d "$HOME/.local/veda-server" ]; then
  step "removing $HOME/.local/veda-server/ (server + .venv)..."
  rm -rf "$HOME/.local/veda-server"
fi

# 3. Launcher entry
if [ -f "$HOME/.local/share/applications/veda.desktop" ]; then
  step "removing launcher entry..."
  rm -f "$HOME/.local/share/applications/veda.desktop"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
  fi
fi

# 4. Desktop shortcut
if [ -f "$HOME/Desktop/veda.desktop" ]; then
  step "removing desktop shortcut..."
  rm -f "$HOME/Desktop/veda.desktop"
fi

# 5. GNOME taskbar pin
if command -v gsettings >/dev/null 2>&1; then
  current="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '')"
  if printf '%s' "$current" | grep -q "veda.desktop"; then
    step "removing veda.desktop from GNOME favorites..."
    new=$(printf '%s' "$current" | sed -E "s/, ?'veda.desktop'//; s/'veda.desktop', ?//; s/'veda.desktop'//")
    gsettings set org.gnome.shell favorite-apps "$new" 2>/dev/null || true
  fi
fi

# 6. User data
if [ -d "$HOME/.veda" ]; then
  if [ "$PURGE_DATA" = "1" ]; then
    step "purging user data at $HOME/.veda/ (--purge-user-data)..."
    rm -rf "$HOME/.veda"
  else
    step "keeping user data at $HOME/.veda/ (pass --purge-user-data to also remove)"
  fi
fi

printf '\n[uninstall] done\n'
