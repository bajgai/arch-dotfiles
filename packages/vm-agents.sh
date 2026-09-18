#!/usr/bin/env bash
# Install the agent-workflow tools on the Omarchy VM. Idempotent; no sudo.
#   1. Pin every mise tool listed in packages/vm-agents.lock (Omarchy's own
#      install path for agent CLIs, so omarchy-update keeps owning mise).
#   2. Install hcom and Beads Rust (br) from their GitHub release tarballs,
#      verified against the same sha256 values ~/dotfiles pins on the Mac.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="$HERE/vm-agents.lock"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

# --- 1. mise pins -----------------------------------------------------------
command -v mise >/dev/null || { echo "mise is required (Omarchy ships it)"; exit 1; }
pins=()
while IFS= read -r line; do
  line="${line%%#*}"
  [[ $line =~ ^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]] || continue
  pins+=("${BASH_REMATCH[1]}@${BASH_REMATCH[2]}")
done < "$LOCK"
if ((${#pins[@]})); then
  echo "==> mise pins: ${pins[*]}"
  mise use -g "${pins[@]}"
fi

# --- 2. hcom + br release tarballs ------------------------------------------
# Versions and checksums mirror ~/dotfiles/pkgs/hcom.nix and pkgs/beads-rust.nix.
HCOM_VERSION=0.7.25
HCOM_SHA256=9b5c8c8f76cb5d623a10823ce5303781351b7c430083821ab6fb6230fc11ec9a
BR_VERSION=0.5.10
BR_SHA256=a9e06c203fba0a13f7dcac058bad45d3d3546b19f2fcc5a4b010c6c720603e9e

[[ $(uname -m) == aarch64 ]] || { echo "checksums below are for aarch64 only"; exit 1; }

fetch_verified() { # url sha256 dest
  local url=$1 sum=$2 dest=$3
  curl -fsSL --retry 3 -o "$dest" "$url"
  echo "$sum  $dest" | sha256sum -c - >/dev/null || { echo "checksum mismatch: $url"; rm -f "$dest"; exit 1; }
}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

if [[ "$("$BIN/hcom" --version 2>/dev/null || true)" != *"$HCOM_VERSION"* ]]; then
  echo "==> hcom $HCOM_VERSION"
  fetch_verified "https://github.com/aannoo/hcom/releases/download/v${HCOM_VERSION}/hcom-aarch64-unknown-linux-musl.tar.gz" "$HCOM_SHA256" "$tmp/hcom.tar.gz"
  tar -xzf "$tmp/hcom.tar.gz" -C "$tmp"
  install -m 0755 "$tmp"/hcom*/hcom "$BIN/hcom"
fi
# hcom has no switch for its daily GitHub version probe; pin the flag far ahead.
( umask 077; mkdir -p "$HOME/.hcom/.tmp/flags"; touch -d '2099-01-01 UTC' "$HOME/.hcom/.tmp/flags/update_check" )

if [[ "$("$BIN/br" --version 2>/dev/null || true)" != *"$BR_VERSION"* ]]; then
  echo "==> br $BR_VERSION"
  fetch_verified "https://github.com/Dicklesworthstone/beads_rust/releases/download/v${BR_VERSION}/br-${BR_VERSION}-linux_musl_arm64.tar.gz" "$BR_SHA256" "$tmp/br.tar.gz"
  tar -xzf "$tmp/br.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/br" "$BIN/br"
fi

echo "==> installed: $("$BIN/hcom" --version 2>&1 | head -1); $("$BIN/br" --version 2>&1 | head -1)"
