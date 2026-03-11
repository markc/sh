# CLAUDE.md

Guidance for Claude Code working with this repository.

## RC — Shell Configuration Toolkit

Bash-exclusive cross-platform shell config (aliases, functions, tools) for system administration. Rejects non-bash shells with an install hint.

**`rcm`** is the single management tool: bootstraps shell config, manages SSH hosts/keys, deploys `~/.rc` to remotes. Run `rcm ha` for full built-in help.

## Architecture

### Load Chain

```
~/.bashrc → source ~/.rc/_shrc (core: OS detection, aliases, functions, prompt)
               → source ~/.myrc (machine-local overrides, not in git)
                    → source ~/.rc/_shrc.d/*.sh (opt-in server modules)
```

### Key Files

| File | Purpose |
|------|---------|
| `_shrc` | Core (~324 lines): OS detection, universal aliases, service control, prompt |
| `rcm` | RC Manager (~625 lines): shell init, SSH hosts/keys, deploy, sshd |
| `_shrc.d/server.sh` | DKIM management, user creation, vhost navigation |
| `_shrc.d/logs.sh` | Mail/web/DNS log tail aliases |
| `_shrc.d/net.sh` | WHOIS lookups, firewall aliases |

### Core Variables (`_shrc`)

| Variable | Purpose |
|----------|---------|
| `OSTYP` | Auto-detected OS: `alpine`, `debian`, `cachyos`, `arch`, `openwrt`, `macos` |
| `ARCH` | Auto-detected architecture: `x86_64`, `arm64`, `armv7` |
| `SUDO` | `/usr/bin/sudo ` if non-root, empty if root |
| `COLOR` | Prompt color (default `31`, override in `~/.myrc`) |
| `LABEL` | Prompt label (default `hostname`, override in `~/.myrc`) |

### OS Abstraction

`_shrc` detects OS via `/etc/os-release` and sets `OSTYP`. Package aliases (`i`=install, `r`=remove, `s`=search, `u`=upgrade) and service control (`sc`) adapt per OS automatically. Same interface, different backends.

## Installation

```bash
git clone https://github.com/markc/rc ~/.rc
~/.rc/rcm init          # Set up this machine (shell + SSH)
source ~/.bashrc         # Activate
```

On Alpine/OpenWRT, install bash first. Deploy to remote: `rcm create HOST IP && rcm sync HOST`.

## Key Aliases and Functions

- **Navigation:** `..` (cd ..), `la` (ls -lFAh), `e`/`se` (nano/sudo nano), `es` (edit ~/.myrc + reload)
- **Diagnostics:** `health`, `ports`, `procs`, `mem`, `disk`, `ram`, `logs`, `f` (find), `p` (grep procs)
- **Packages:** `i` (install), `r` (remove), `s` (search), `u` (upgrade) — maps to native pkg manager
- **Services:** `sc start|stop|restart|enable SERVICE` — wraps systemd/OpenRC/init.d
- **SSH:** `sx host "command"` — SSH with interactive shell

## rcm Commands (run `rcm ha` for full reference)

- **Setup:** `init`, `sync HOST`
- **Hosts:** `create`, `read`, `update`, `delete`, `list`, `test`
- **Keys:** `key_create`, `key_read`, `key_delete`, `key_list` (Ed25519, 100 KDF rounds)
  - `key_create` and `key_read` default to name `default` — `rcm kc` creates `~/.ssh/keys/default`
  - `create` uses `~/.ssh/keys/default` when no key specified
- **Git:** `pull`, `push [message]`
- **Utils:** `perms`, `start`, `stop`

## Server Modules (`_shrc.d/`)

Opt-in via `~/.myrc`. See each file for available commands:
- **server.sh** — DKIM (`adddkim`/`chdkim`/`deldkim`), users (`newuser`/`chrootuser`), vhosts (`go2`/`shhost`)
- **logs.sh** — `mlog`, `alog`, `elog`, `dlog`
- **net.sh** — `shwho` (WHOIS summary), `shblock` (blocked IPs)

## Validation

```bash
bash -n _shrc && bash -n rcm                      # Syntax check core
for f in _shrc.d/*.sh; do bash -n "$f"; done       # Syntax check modules
rcm init                                            # Idempotent setup
rcm test                                            # TCP connectivity check
```

## Conventions

- **Bash required** — `_shrc` guards against non-bash shells at load time
- **Single tool** — `rcm` handles everything
- **Idempotent** — `rcm init`, `rcm perms` are safe to repeat
- **Ed25519 only** — SSH keys use ed25519 with 100 KDF rounds
- **No Docker** — Uses Incus containers or Proxmox VMs
- **OS detection** — Reads `/etc/os-release`, sets `OSTYP`/`ARCH`; all conditional logic branches on these
- **Core vs modules** — `_shrc` loads everywhere; `_shrc.d/` is opt-in via `~/.myrc`
- **Deployment** — `rcm sync <host>` rsyncs `~/.rc` (excluding `.git`), runs `rcm init` on remote
- **Platforms** — Debian/Ubuntu, Arch/CachyOS, Alpine, OpenWRT, macOS (basic)

## License

Copyright (C) 1995-2026 Mark Constable <mc@netserva.org> (MIT License)
