# CLAUDE.md

Guidance for Claude Code working with this repository.

## SH — Shell Configuration Toolkit

Bash-exclusive cross-platform shell config (aliases, functions, tools) for system administration. Rejects non-bash shells with an install hint.

**`sshm`** is the single management tool: bootstraps shell config, manages SSH hosts/keys, deploys `~/.sh` to remotes. Run `sshm ha` for full built-in help.

`README.md` is a symlink to this file — there is one document, not two.

## Architecture

### Load Chain

```
~/.bashrc → source ~/.sh/_shrc (core: OS detection, aliases, functions, prompt)
               → source ~/.myrc (machine-local overrides, not in git)
                    → source ~/.sh/_shrc.d/*.sh (opt-in server modules)
```

`_shrc` also prepends `~/.sh` to `PATH`, so `sshm` is callable after sourcing.

### Key Files

| File | Purpose |
|------|---------|
| `_shrc` | Core (368 lines): OS/arch detection, universal aliases, `sc` service control, functions, colored prompt |
| `sshm` | SSH Manager (695 lines): shell init, SSH hosts/keys, deploy, connectivity test, git, sshd |
| `_bash_profile` / `_bashrc` | Minimal templates copied to `~/` on `sshm init` |
| `_myrc.example` | Template for machine-local `~/.myrc` (prompt color, modules, PATH extensions) |
| `_shrc.d/server.sh` | DKIM management, user creation, vhost navigation |
| `_shrc.d/logs.sh` | Mail/web/DNS log tail aliases |
| `_shrc.d/net.sh` | WHOIS lookups, firewall aliases |

### Core Variables (`_shrc`)

| Variable | Purpose |
|----------|---------|
| `OSTYP` | Auto-detected OS: `alpine`, `debian`, `ubuntu`, `cachyos`, `manjaro`, `arch`, `openwrt`, `macos` (falls back via `ID_LIKE`, then `uname`) |
| `ARCH` | Auto-detected architecture: `x86_64`, `arm64`, `armv7` (else raw `uname -m`) |
| `SUDO` | `/usr/bin/sudo ` if non-root, empty if root |
| `COLOR` | Prompt color (default `31`, override in `~/.myrc`) |
| `LABEL` | Prompt label (default `hostname`, override in `~/.myrc`) |

### OS Abstraction

`_shrc` detects OS via `/etc/os-release` and sets `OSTYP`. Package aliases (`i`=install, `r`=remove, `s`=search, `u`=upgrade, `lspkg`=list) and service control (`sc`) adapt per OS automatically — same interface, different backends (apt / apk / opkg / paru / brew, and systemd / OpenRC / init.d / launchctl).

On Arch/CachyOS/Manjaro `u` upgrades official repos only; `ua` is AUR-only, `uu` everything, `uc` everything + cleanup. macOS also has `uc` (upgrade + cleanup).

## Installation

```bash
git clone https://github.com/markc/sh ~/.sh
~/.sh/sshm init          # Set up this machine (shell + SSH)
source ~/.bashrc         # Activate
```

On Alpine/OpenWRT, install bash first. Deploy to remote: `sshm create HOST IP && sshm sync HOST`.

## Key Aliases and Functions

- **Navigation:** `..` (cd ..), `la`/`ll`/`ls` (dirs-first colored), `e`/`se` (nano / sudo nano), `df` (df -kTh)
- **Search:** `f PATTERN` (find by name), `q PATTERN` (recursive grep), `p PATTERN` (grep processes)
- **Diagnostics:** `health` (full report), `ports`, `procs`, `mem`, `disk`, `ram`, `temp`, `logs`, `syslog`, `authlog`, `services`, `failed`, `failedlogins`, `lastlog`, `pstree_service SVC`, `ff` (fastfetch), `wt URL` (curl timing)
- **Packages:** `i` (install), `r` (remove), `s` (search), `u` (upgrade), `lspkg`, `edpkg` — maps to native pkg manager
- **Services:** `sc start|stop|restart|enable|status SERVICE` (no args = list services) — wraps systemd/OpenRC/init.d/launchctl
- **Users:** `getusers` (UID 1000–9998), `grepuser NAME`
- **SSH:** `sx host "command"` — run a command in a remote interactive bash, job-control noise stripped
- **Notes/help:** `n` (append timestamped note + open `~/.note`), `sn` (show notes), `?` (run `~/.help`), `eh` (edit `~/.help`), `es` (edit `~/.myrc` + reload), `m` (run `~/.menu`)
- **Misc:** `newpw [len]` (default 16, guarantees upper/lower/digit), `chktime FILE SECS` (file older than N secs), `shortname` (MAC-derived host id)

## sshm Reference (`sshm ha`)

Behaviour not obvious from the help text:
- `test` uses `ssh BatchMode=yes` with a 5s timeout and a colour-coded summary.
- Hosts listed in `~/.ssh/hosts/.ephemeral` report `OFFLINE` instead of `FAILED` and survive `--delete-failed`.
- `github.com` is auto-recognised as a git provider (success on `Permission denied (publickey)`).
- `pull` is fast-forward only; `push [MESSAGE]` auto-generates a message from changed file names if omitted, and will push existing commits even when there's nothing new to commit.
- `init` is idempotent: if `~/.bashrc` already exists it just appends the `_shrc` source line if missing.

```
SSHM — SSH Manager
==================
Bootstrap, configure, and deploy the ~/.sh shell toolkit.

SETUP
  sshm init                                         # Set up this machine (shell + SSH)
  sshm sync HOST                                    # Deploy ~/.sh to remote + run init

  init creates (if missing):
    ~/.bash_profile    from ~/.sh/_bash_profile
    ~/.bashrc          from ~/.sh/_bashrc
    ~/.myrc            from ~/.sh/_myrc.example
    ~/.ssh/            NetServa 3.0 structure (hosts/, keys/, mux/, config)

  sync rsyncs ~/.sh/ (excluding .git) to HOST, then runs sshm init remotely.
  ~/.myrc is never synced — each machine keeps its own.

HOST COMMANDS — save servers by nickname
  create NAME IP [PORT] [USER] [KEYFILE]           # Save host (defaults: 22, root, ~/.ssh/keys/default)
  list                                             # Show all saved hosts
  read NAME                                        # Show host config values
  update NAME                                      # Edit host config in nano
  delete NAME                                      # Remove host
  test [NAME] [--delete-failed]                    # Test SSH connectivity

  Examples:
    sshm create web 10.0.0.5                        # Basic — port 22, user root, default key
    sshm create db 10.0.0.6 2222 admin              # Custom port and user
    sshm create pi 192.168.1.50 22 pi ~/k/pi        # With specific key
    sshm test                                       # Test all hosts
    sshm test --delete-failed                       # Test all, remove dead ones

KEY COMMANDS — Ed25519 keypairs for passwordless login
  key_create [NAME] [COMMENT] [PASSPHRASE]         # Create keypair (default name: "default")
  key_list                                         # Show all keys with fingerprints
  key_read [NAME]                                  # Show public key (default name: "default")
  key_delete NAME                                  # Remove keypair

  Examples:
    sshm key_create                                 # Create default key (no passphrase)
    sshm key_create work "Laptop" "secret"          # Named key with comment and passphrase
    ssh-copy-id -i ~/.ssh/keys/default.pub u@server  # Deploy key to server

GIT — update and publish ~/.sh
  pull                                             # Fetch upstream, pull if newer
  push [MESSAGE]                                   # Commit all changes + push

  Examples:
    sshm pull                                       # Check for updates
    sshm push                                       # Commit + push (auto message)
    sshm push "Add custom aliases"                  # Commit + push with message

UTILITIES
  sshm perms                                        # Fix ~/.ssh permissions (after rsync)

SERVICE (sudo required)
  sshm start                                        # Start sshd (no auto-boot)
  sshm stop                                         # Stop sshd, disable, drop INCOMING

SHORTCUTS
  i=init  s=sync                                   # Setup
  c=create  r=read  u=update  d=delete             # Hosts
  l=list  t=test  p=perms                          # Hosts/utils
  kc=key_create  kr=key_read  kd=key_delete  kl=key_list  # Keys
  pull  push                                       # Git
  h=help  ha=help all                              # Help

FILES
  ~/.sh/_shrc         Core shell toolkit (sourced by ~/.bashrc)
  ~/.sh/_shrc.d/      Optional server modules (loaded via ~/.myrc)
  ~/.myrc             Personal config (machine-local, never synced)
  ~/.ssh/hosts/*      Individual SSH host configs
  ~/.ssh/keys/*       Ed25519 keypairs
  ~/.ssh/mux/*        ControlMaster multiplexing sockets
```

## Server Modules (`_shrc.d/`)

Opt-in by sourcing from `~/.myrc`. See each file for the full command set:
- **server.sh** — DKIM (`shdkim`/`adddkim`/`chdkim`/`deldkim`), users (`newuser`/`chrootuser`), vhosts (`go2`/`shhost`)
- **logs.sh** — `mlog`, `mgrep`, `alog`, `elog`, `plog`, `dlog`, `maillog`
- **net.sh** — `shwho` (WHOIS + DNS/MX summary), `shblock` (nftables sshguard blocklist)

## Validation

```bash
bash -n _shrc && bash -n sshm                      # Syntax check core
for f in _shrc.d/*.sh; do bash -n "$f"; done       # Syntax check modules
sshm init                                          # Idempotent setup
sshm test                                          # SSH connectivity check
```

## Conventions

- **Bash required** — `_shrc` guards against non-bash shells at load time
- **Bash ≥ 4 for `sshm test`** — uses associative arrays; macOS needs `brew install bash`
- **Single tool** — `sshm` handles everything
- **Idempotent** — `sshm init`, `sshm perms` are safe to repeat
- **Ed25519 only** — SSH keys use ed25519 with 100 KDF rounds
- **No Docker** — Uses Incus containers or Proxmox VMs
- **OS detection** — Reads `/etc/os-release`, sets `OSTYP`/`ARCH`; all conditional logic branches on these
- **Core vs modules** — `_shrc` loads everywhere; `_shrc.d/` is opt-in via `~/.myrc`
- **Everything versioned** — no `.gitignore` exclusions; personal config lives in `~/.myrc` outside the repo
- **Deployment** — `sshm sync <host>` rsyncs `~/.sh` (excluding `.git`), runs `sshm init` on remote
- **Platforms** — Debian/Ubuntu, Arch/CachyOS/Manjaro, Alpine, OpenWRT, macOS (Homebrew + launchctl, never sudo brew)

## License

Copyright (C) 1995-2026 Mark Constable <mc@netserva.org> (MIT License)
