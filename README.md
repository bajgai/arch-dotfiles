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
  dot_config/hypr/    Omarchy user overrides (desktop only)
packages/             pacman manifests: common / vm / vps
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
- `home/dot_config/hypr/*.conf` are placeholders. Replace them with the real
  override files from the VM (`ls ~/.config/hypr` to see what exists).
- **Shell not yet settled.** This repo manages `dot_zshrc.tmpl`, but Omarchy
  ships bash as the login shell with a `~/.bashrc` that sources
  `~/.local/share/omarchy/default/bash/rc`. So either the zshrc is never
  loaded on the VM, or switching with `chsh` drops Omarchy's shell defaults.
  Check `echo $SHELL` and `head -5 ~/.bashrc` on the VM, then decide: manage
  `.bashrc` while preserving Omarchy's source line, or commit to zsh knowingly.
- The templates here (`promptBoolOnce`, the `.chezmoiignore` conditional,
  `.chezmoiroot`) are unverified — chezmoi is not installed on the Mac, so they
  are first exercised by `bootstrap.sh` on a target machine.
