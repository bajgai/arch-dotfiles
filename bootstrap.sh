#!/usr/bin/env bash
# Bootstrap an Arch box (Omarchy VM or VPS) from this repo.
# Run ON the target machine. Safe to re-run.
set -euo pipefail

REPO_URL="${REPO_URL:-}"   # e.g. git@github.com:you/arch-dotfiles.git
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v pacman >/dev/null || { echo "not an Arch system"; exit 1; }

echo "==> installing chezmoi"
command -v chezmoi >/dev/null || sudo pacman -S --needed --noconfirm chezmoi

echo "==> applying dotfiles"
if [ -n "$REPO_URL" ]; then
  chezmoi init --apply "$REPO_URL"
else
  chezmoi init --apply --source "$HERE"
fi

# Which package sets apply here? chezmoi recorded the answer at init time.
DESKTOP="$(chezmoi data | grep -o '"desktop": *[a-z]*' | awk '{print $2}')"
SETS=("$HERE/packages/common.txt")
if [ "$DESKTOP" = "true" ]; then
  SETS+=("$HERE/packages/vm.txt")
else
  SETS+=("$HERE/packages/vps.txt")
fi

echo "==> installing packages from: ${SETS[*]}"
mapfile -t PKGS < <(cat "${SETS[@]}" | sed 's/#.*//' | tr -d '[:blank:]' | grep -v '^$' | sort -u)
if [ "${#PKGS[@]}" -gt 0 ]; then
  sudo pacman -S --needed --noconfirm "${PKGS[@]}"
fi

if [ "$DESKTOP" = "true" ]; then
  echo "==> installing sync-to-vps"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$HERE/bin/sync-to-vps" "$HOME/.local/bin/sync-to-vps"
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/arch-dotfiles"
  CONF="${XDG_CONFIG_HOME:-$HOME/.config}/arch-dotfiles/sync.conf"
  [ -f "$CONF" ] || cat > "$CONF" <<'CONFEOF'
# Where sync-to-vps reads from and writes to.
SRC="$HOME/sync"
REMOTE="vps"
DEST="/root/sync"
CONFEOF
fi

echo "==> done"
