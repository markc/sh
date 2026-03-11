# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## RC — Shell Configuration Toolkit

Bash-exclusive shell configuration providing cross-platform aliases, functions, and tools for system administration. Requires bash (not ash/dash/sh) — will reject non-bash shells with an install hint.

## Architecture

### Load Chain

```
~/.bashrc
  └─> source ~/.rc/_shrc        # Core (OS detection, aliases, functions, prompt)
        └─> source ~/.myrc       # Personal overrides (machine-local, not in git)
              └─> source ~/.rc/_shrc.d/server.sh   # Optional: DKIM, users, vhosts
              └─> source ~/.rc/_shrc.d/logs.sh     # Optional: mail/web/DNS logs
              └─> source ~/.rc/_shrc.d/net.sh      # Optional: WHOIS, firewall
```

- `_shrc` is the core (323 lines) — synced to all remotes via `rcm sync`
- `~/.myrc` is machine-local (created from `_myrc.example`, never versioned)
- `_shrc.d/` modules are opt-in — source the ones you need from `~/.myrc`

### Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `_shrc` | 323 | Core: OS detection, universal aliases, service control, prompt |
| `sshm` | 510 | SSH host/key manager (NetServa 3.0 directory structure) |
| `rcm` | 125 | RC deployment: local init + remote rsync |
| `_shrc.d/server.sh` | 216 | DKIM management, user creation, vhost navigation |
| `_shrc.d/logs.sh` | 11 | Mail/web/DNS log tail aliases |
| `_shrc.d/net.sh` | 39 | WHOIS lookups, firewall aliases |

### Variables Set by `_shrc`

| Variable | Source | Purpose |
|----------|--------|---------|
| `OSTYP` | Auto-detected | OS type: `alpine`, `debian`, `cachyos`, `arch`, `openwrt`, `macos` |
| `ARCH` | Auto-detected | Architecture: `x86_64`, `arm64`, `armv7` |
| `SUDO` | Auto-detected | `/usr/bin/sudo ` if non-root, empty if root |
| `COLOR` | Default `31` | Prompt color (override in `~/.myrc`) |
| `LABEL` | Default `hostname` | Prompt label (override in `~/.myrc`) |
| `PATH` | Set then extended | usr-merge base + `~/.rc` appended |

### OS Abstraction Pattern

`_shrc` detects OS via `/etc/os-release` and sets `OSTYP`. Package aliases (`i`, `r`, `s`, `u`) and service control (`sc`) adapt per OS automatically. Same interface, different backends.

## Installation

```bash
git clone https://github.com/markc/rc ~/.rc
~/.rc/rcm init          # Creates ~/.bash_profile, ~/.bashrc, ~/.myrc from templates
source ~/.bashrc         # Activate (or open new shell)
```

On Alpine/OpenWRT, install bash first: `apk add bash` / `opkg install bash`

### Deploy to a Remote Server

```bash
sshm create webbox 10.0.0.5          # Save the host
rcm sync webbox                       # Rsync ~/.rc + run init on remote
```

### Enable Server Modules

Add to `~/.myrc` on machines that need them:

```bash
# On a mail/web server:
source ~/.rc/_shrc.d/server.sh
source ~/.rc/_shrc.d/logs.sh
source ~/.rc/_shrc.d/net.sh
```

## Everyday Usage

### Universal Package Management

Same aliases work on every OS — `_shrc` maps them to the native package manager:

| Alias | Alpine (apk) | Debian (apt) | Arch (paru) | OpenWRT (opkg) |
|-------|-------------|-------------|-------------|----------------|
| `i` | `apk add` | `apt-get install` | `paru -S` | `opkg install` |
| `r` | `apk del` | `apt-get remove --purge` | `paru -Rns` | `opkg remove` |
| `s` | `apk search` | `apt-cache search` | `paru -Ss` | `opkg list` |
| `u` | `apk update && upgrade` | `apt update && dist-upgrade` | `paru -Syu` | `opkg update && upgrade` |

### Service Control

`sc` wraps systemd, OpenRC, and OpenWRT init into one interface:

| OS | Implementation |
|----|---------------|
| Debian/Arch (systemd) | `systemctl <action> <service>` |
| Alpine (OpenRC) | `rc-service <service> <action>` |
| OpenWRT | `/etc/init.d/<service> <action>` |

```bash
sc start nginx          # Works on any supported OS
sc stop nginx
sc restart nginx
sc enable nginx
sc                      # List all services
```

### Navigation and Editing

```bash
..                      # cd ..
la                      # ls -lFAh with color, dirs first
e somefile              # nano with nice defaults (-t -x -c)
se /etc/somefile        # sudo nano
es                      # Edit ~/.myrc and reload everything
```

### Quick Diagnostics

```bash
health                  # Full system health check (memory, disk, load, ports, failed logins)
ports                   # ss -tuln (listening ports)
procs                   # Top 20 CPU processes
mem                     # free -h
disk                    # df -h
ram                     # Processes sorted by memory usage
logs                    # journalctl -f
f pattern               # Find files by name
p pattern               # Find processes by name
```

### SSH Manager (sshm)

See `sshm.md` for full reference.

```bash
sshm init                              # First-time setup (creates ~/.ssh structure)
sshm create myserver 10.0.0.5          # Save a host (defaults: port 22, user root)
sshm create db 10.0.0.6 2222 admin     # Custom port and user
ssh myserver                            # Connect using saved config

sshm list                               # Show all hosts
sshm test                               # TCP test all hosts
sshm test myserver                      # Test one host
sshm test --delete-failed               # Test all, remove dead ones

sshm key_create work                    # Create Ed25519 keypair
sshm key_list                           # Show key fingerprints
ssh-copy-id -i ~/.ssh/keys/work.pub u@host  # Deploy key

# Shortcuts: c=create l=list r=read u=update d=delete t=test
#            kc=key_create kl=key_list kr=key_read kd=key_delete
```

### Remote Command Execution

```bash
sx hostname "command"   # SSH with interactive shell (filters noise)
```

### Personal Configuration (~/.myrc)

Override defaults per-machine without touching versioned files:

```bash
COLOR=32                # Green prompt (default: 31 red)
LABEL="webserver"       # Prompt label (default: hostname)
export PATH="$HOME/bin:$PATH"
alias proj='cd ~/projects'

# Load server modules on this machine
source ~/.rc/_shrc.d/server.sh
```

Edit anytime with `es` — it opens `~/.myrc` in nano, then reloads everything.

## Server Modules (`_shrc.d/`)

### server.sh — DKIM, Users, Vhosts

```bash
go2 example.com         # cd /srv/example.com*/web/app
shhost                   # List all vhosts in /srv/
newuser admin            # Create user with random password
chrootuser backupuser    # Setup chroot SFTP

shdkim                   # List all DKIM keys
adddkim example.com      # Generate DKIM key + update OpenDKIM config
chdkim example.com       # Rotate DKIM key
deldkim example.com      # Remove DKIM key
```

### logs.sh — Service Log Tailing

```bash
mlog                     # tail -f /var/log/mail.log
alog                     # tail -f nginx access.log
elog                     # tail -f nginx error.log
dlog                     # journalctl -u pdns -f
```

### net.sh — Network Diagnostics

```bash
shwho example.com        # WHOIS + DNS + MX + PTR summary
shblock                  # Show nftables/sshguard blocked IPs
```

## Bootstrap Naming

`shortname` alias generates a 5-character identifier (e.g. `n1a2b`) from the first ethernet MAC address. Used as a temporary hostname when bootstrapping a new machine until a human assigns a meaningful name. The `n` prefix ensures it's a valid hostname.

## Validation

```bash
bash -n _shrc && bash -n sshm && bash -n rcm    # Syntax check core
for f in _shrc.d/*.sh; do bash -n "$f"; done     # Syntax check modules
rcm init                                          # Idempotent local setup
sshm init                                         # Creates ~/.ssh NS 3.0 structure
sshm test                                         # TCP connectivity check
```

## Conventions

- **Bash required**: `_shrc` guards against non-bash shells at load time
- **Idempotent commands**: `rcm init`, `sshm init`, `sshm perms` are all safe to repeat
- **Ed25519 only**: SSH keys use ed25519 with 100 KDF rounds
- **No Docker**: Uses Incus containers or Proxmox VMs
- **PATH**: Follows usr-merge standard (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`)
- **OS detection**: Reads `/etc/os-release`, sets `OSTYP` and `ARCH` — all conditional logic branches on these
- **Deployment flow**: `rcm sync <host>` rsyncs `~/.rc` (excluding `.git`), then runs `rcm init` on remote
- **Core vs modules**: `_shrc` loads on every machine; server-specific code lives in `_shrc.d/` and is opt-in via `~/.myrc`

## Supported Platforms

- Debian/Ubuntu (apt, systemd)
- Arch/Manjaro/CachyOS (pacman/paru, systemd)
- Alpine Linux (apk, OpenRC)
- OpenWRT (opkg, init.d)
- macOS (basic support)

## License

Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License)
