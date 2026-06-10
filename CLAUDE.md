# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Pure Bash. A one-shot Linux server optimizer (sysctl/SSH/ulimits/swap/UFW tuning + XanMod kernel). No build system, no tests, no CI, no dependencies to install in this repo — the deliverable *is* the shell scripts.

## Commands

There is no build/lint/test harness. Validate changes with:

```bash
shellcheck linux-optimizer.sh scripts/*.sh   # static lint (not configured in-repo; install separately)
bash -n scripts/ubuntu-optimizer.sh          # syntax-only parse check
```

Running for real requires **root on a matching Linux distro** — the scripts mutate `/etc/sysctl.conf`, `/etc/ssh/sshd_config`, `/etc/profile`, `/etc/fstab`, install kernels, and restart services. They cannot be meaningfully executed on this Windows dev host; test in a throwaway VM (Ubuntu 20+, Debian 11+, CentOS Stream 8+, AlmaLinux 8+, Fedora 37+) per the README's supported matrix. Each distro script presents an interactive numbered menu (`main` loop); option `1` = "Apply Everything".

## Architecture

**Two-stage delivery.** `linux-optimizer.sh` is the bootstrap entry point. It does NOT contain the optimization logic — it: checks root → installs prereqs (`wget curl sudo jq`) → fixes `/etc/hosts`, `/etc/resolv.conf` (Cloudflare DNS), timezone (via `ip-api.com`, best-of-3 consensus) → detects the distro by parsing `NAME=` from `/etc/os-release` → `wget`s the matching `scripts/<distro>-optimizer.sh` from `raw.githubusercontent.com/LivingG0D/linux-optimizer/main/... (with a jsDelivr CDN fallback)` and `bash`es it. AlmaLinux reuses the CentOS script.

**Deployment = push to `main`.** Because the bootstrap fetches the distro scripts from the `main` branch raw URLs at runtime, any merge to `main` is immediately live for every user. There is no versioning or release step. Edits to `scripts/*.sh` are "shipped" the moment they land on `main`.

**Four near-duplicate distro scripts.** `scripts/{ubuntu,debian,centos,fedora}-optimizer.sh` are parallel copies of the same program, each self-contained (color `*_msg` helpers, path vars, the same set of optimization functions, `show_menu`, `main` dispatch loop, `apply_everything`). **A behavioral change almost always has to be mirrored across all four** (plus the `files/` reference). They diverge only here:
- Package manager: `apt` (ubuntu, debian) vs `dnf` (centos, fedora).
- XanMod kernel install + `disable_terminal_ads`: **ubuntu & debian only** → their menus have 13 options; centos & fedora have 11 (no XanMod).
- SSH service name on restart: `ssh` (ubuntu, debian) vs `sshd` (centos, fedora).

**`files/` is reference-only, not runtime.** `files/sysctl.conf`, `files/sshd_config`, `files/profile` are the canonical/documented versions of what the scripts inject. The scripts do **not** read them — they embed the same content inline (heredocs / `tee -a`). Keep `files/` in sync when you change the injected values.

## Conventions to preserve when editing

- **Idempotent rewrites.** Every optimizer first strips its own keys (`sed -e '/key/d' ...`) then re-appends fresh values, so re-running is safe and doesn't duplicate lines. Follow this delete-then-append pattern for any new sysctl/SSH/ulimit setting, and add the matching delete line.
- **Back up before mutating.** Configs are copied to `*.bak` (`/etc/sysctl.conf.bak`, `/etc/ssh/sshd_config.bak`, etc.) before edits. Preserve this.
- **Menu ⇄ function dispatch.** User-facing flows are composed in `main`'s `case` from named functions; `apply_everything` (menu option 1) is the full pipeline. New features = a new function + wiring into `show_menu`, the `case`, and usually `apply_everything` — across all relevant distro scripts.
- The interactive `read`/`sleep`-paced UX and `tput` colored output are intentional; match the existing cadence.
