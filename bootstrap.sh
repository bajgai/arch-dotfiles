#!/usr/bin/env bash
# Bootstrap an Arch box (Omarchy VM or VPS) from this repo.
# Run ON the target machine, from inside the cloned repo. Safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v pacman >/dev/null || { echo "not an Arch system"; exit 1; }

# Minimal Arch installs often lack sudo, and root does not need it.
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO=sudo

echo "==> installing chezmoi"
command -v chezmoi >/dev/null || $SUDO pacman -S --needed --noconfirm chezmoi

# This clone is the single source. chezmoi records it as sourceDir, so later
# `chezmoi diff` / `chezmoi apply` operate on this repo and nothing drifts.
echo "==> applying dotfiles"
chezmoi init --apply --source "$HERE"

DESKTOP="$(chezmoi execute-template '{{ .desktop }}')"

SETS=("$HERE/packages/common.txt")
if [ "$DESKTOP" = "true" ]; then
  SETS+=("$HERE/packages/vm.txt")
else
  SETS+=("$HERE/packages/vps.txt")
fi

echo "==> installing packages from: ${SETS[*]}"
mapfile -t PKGS < <(cat "${SETS[@]}" | sed 's/#.*//' | tr -d '[:blank:]' | grep -v '^$' | sort -u)
if [ "${#PKGS[@]}" -gt 0 ]; then
  $SUDO pacman -S --needed --noconfirm "${PKGS[@]}"
fi

if [ "$DESKTOP" = "true" ]; then
  # Omarchy ships bash as the login shell. This repo manages zsh, and the
  # desktop branch of dot_zshrc.tmpl sources Omarchy's env-bootstrap so its
  # PATH and mise setup survive the switch. chsh asks for the user's password.
  ZSH_BIN="$(command -v zsh)"
  if [ -n "$ZSH_BIN" ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
    echo "==> switching login shell to $ZSH_BIN"
    chsh -s "$ZSH_BIN"
  fi

  echo "==> agent CLIs, hcom and br"
  "$HERE/packages/vm-agents.sh"

  echo "==> installing sync-to-vps"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$HERE/bin/sync-to-vps" "$HOME/.local/bin/sync-to-vps"
  CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/arch-dotfiles"
  mkdir -p "$CONFDIR"
  [ -f "$CONFDIR/sync.conf" ] || cat > "$CONFDIR/sync.conf" <<'CONFEOF'
# Where sync-to-vps reads from and writes to.
SRC="$HOME/sync"
REMOTE="vps"
DEST="/root/sync"
CONFEOF
fi

echo
echo "==> done. Verify chezmoi points at this repo:"
echo "    chezmoi source-path   # should print inside $HERE"
