# arch-dotfiles

Shell and tool configuration for the two **Arch Linux** machines:

| Machine | Role | `desktop` |
|---|---|---|
| Omarchy VM (QEMU on the Mac) | Arch + Hyprland desktop | `true` |
| Hostinger VPS | headless Arch server | `false` |

## Scope boundary

This repo owns the **Arch boxes only**.

- The **Mac** is managed by `~/dotfiles` (nix-darwin + Home Manager). It is the
  source of truth for everything on macOS and is not touched by this repo.
- **Omarchy owns its own files.** Omarchy's defaults live in
  `~/.local/share/omarchy/default/hypr/` and are updated by `omarchy-update`.
  This repo manages only the *user override* files in `~/.config/hypr/`, which
  Omarchy sources last. `hyprland.conf` itself stays under Omarchy's control —
  managing it here would fight `omarchy-update`.
- The VPS also serves as the encrypted Restic backup target. Nothing here goes
  near that dedicated SFTP account, its key, or `/repository`.

## Layout

```
.chezmoiroot          -> "home", so only home/ is applied
home/                 chezmoi source directory
  .chezmoi.toml.tmpl  prompts once for `desktop` and `hostnick`
  .chezmoiignore      excludes .config/hypr on non-desktop machines
  dot_zshrc.tmpl      shared shell, with per-machine branches
  dot_config/hypr/    Omarchy user overrides, Lua (desktop only)
packages/             pacman manifests: common / vm / vps
  omarchy-4.0.2-base.txt  what Omarchy itself ships (reference, not installed)
  vm-agents.lock      exact mise pins for the agent CLIs
  vm-agents.sh        applies the pins; installs hcom and br with checksums
bin/sync-to-vps       one-way file sync, VM -> VPS
bootstrap.sh          run on a target machine to set it up
```

## Setup on a machine

```sh
git clone <this repo> ~/src/arch-dotfiles
~/src/arch-dotfiles/bootstrap.sh
```

It prompts once for whether the machine is a desktop and for a short nickname,
then applies the dotfiles and installs the matching package set.

The clone is the single source of truth: `bootstrap.sh` records it as chezmoi's
`sourceDir`, so there is never a second copy under `~/.local/share/chezmoi` to
drift from. Confirm after the first run:

```sh
chezmoi source-path   # must print a path inside your clone
```

Day to day:

```sh
chezmoi add ~/.config/foo/bar    # start managing a file
chezmoi diff                     # preview pending changes
chezmoi apply                    # apply them
```

## Plain-file sync (VM -> VPS)

Files you drop in `~/sync` on the Omarchy VM are pushed to `/root/sync` on the
VPS. One-way by design: the VPS is a destination, never a source.

```sh
sync-to-vps --dry-run    # preview
sync-to-vps              # transfer
sync-to-vps --delete     # also mirror deletions (prompts first)
```

Paths are configurable in `~/.config/arch-dotfiles/sync.conf`.

**Prerequisite:** the VM needs its own SSH access to the VPS — generate a key on
the VM, add its public half to the VPS, and add a `Host vps` entry to the VM's
`~/.ssh/config`. Do not copy the Mac's key into the VM.

## Known follow-ups

- The VPS is currently accessed as `root`. A normal user there is the better end
  state; `chezmoi` will then write to that user's home instead of `/root`.
- `home/dot_config/hypr/*.lua` are still placeholders; add real overrides as
  they are needed.
- Shell decision, made 2026-09-13: zsh, switched by `bootstrap.sh` with `chsh`.
  The desktop branch of `dot_zshrc.tmpl` sources Omarchy's
  `/usr/share/omarchy/default/bash/env-bootstrap` (its single source of truth
  for `OMARCHY_PATH`, the mise shims and `~/.local/bin`) and runs
  `mise activate zsh`, so Omarchy's tools stay on PATH. Omarchy's bash aliases
  and functions are not carried over.
- `cursor-agent` is not in the guest's mise registry (mise 2026.8.11). Add it
  to `vm-agents.lock` once `omarchy-update` delivers a newer mise.
- Verify once after the first `omarchy-update` that `mise up` left the exact
  pins in `vm-agents.lock` untouched.
- The chezmoi templates were dry-run against the real VM on 2026-09-13
  (`chezmoi apply --dry-run` with `desktop=true`); the VPS branch is still
  untested.
