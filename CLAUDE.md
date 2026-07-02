# CLAUDE.md

Guidance for Claude Code working in this repository. This file is for Claude
only — the human-facing manual is `README.md` (a real file, no longer a symlink
to this one). When behaviour changes, update **both** in the same commit.

## What This Repo Is

**SH** — a bash-exclusive, cross-platform shell configuration toolkit
(aliases, functions, prompt, SSH management) for system administration,
installed at `~/.sh` on every machine. One management tool (`sshm`) bootstraps
the shell config, manages SSH hosts/keys, and deploys `~/.sh` to remotes.
The repo IS the live config on this machine — edits take effect on the next
`source ~/.sh/_shrc` (or the `es` alias).

## File Map

| File | Lines | Purpose |
|------|-------|---------|
| `_shrc` | 370 | Core, sourced by `~/.bashrc`: bash guard, OS/arch detection, all aliases, `sc` service wrapper, functions, PATH baseline, prompt |
| `sshm` | 734 | The only executable: shell init, SSH host/key CRUD, connectivity test, deploy (`sync`), git `pull`/`push`, sshd start/stop |
| `_bash_profile` | template | Copied to `~/.bash_profile` by `sshm init` — sources `/etc/profile` then `~/.bashrc` |
| `_bashrc` | template | Copied to `~/.bashrc` by `sshm init` — one guarded `source ~/.sh/_shrc` line |
| `_myrc.example` | template | Copied to `~/.myrc` by `sshm init` — machine-local overrides, never versioned or synced |
| `_shrc.d/server.sh` | 216 | Opt-in module: DKIM (`shdkim`/`adddkim`/`chdkim`/`deldkim`), users (`newuser`/`chrootuser`), vhosts (`go2`/`shhost`) |
| `_shrc.d/logs.sh` | 11 | Opt-in module: mail/web/DNS log tail aliases (`mlog`, `alog`, `elog`, `dlog`, `maillog`, …) |
| `_shrc.d/net.sh` | 39 | Opt-in module: `shwho` WHOIS+DNS summary, `shblock` nftables sshguard blocklist |
| `README.md` | — | The complete user manual (beginner → advanced). Keep in sync with code |

## Load Chain

```
login shell:      ~/.bash_profile → /etc/profile → ~/.bashrc
interactive:      ~/.bashrc → source ~/.sh/_shrc
_shrc order:      bash guard → expand_aliases → detect_os (OSTYP/ARCH)
                  → SUDO → aliases (per-OS branches) → functions
                  → PATH baseline (RESET, /opt/cosmix/bin first)
                  → COLOR/LABEL defaults → source ~/.myrc
                  → PS1 → prepend ~/.sh to PATH
~/.myrc:          user overrides + optional `source ~/.sh/_shrc.d/*.sh`
```

Ordering facts that matter when editing `_shrc`:

- `_shrc` **resets PATH** to a fixed baseline (`_shrc:356`) before sourcing
  `~/.myrc`, so anything prepended earlier in the session is wiped; `~/.myrc`
  PATH extensions and the final `~/.sh` prepend (`_shrc:370`) survive.
- `~/.myrc` is sourced **after** aliases/functions (can override anything) and
  **before** PS1 (so `COLOR`/`LABEL` overrides take effect).
- `shopt -s expand_aliases` runs early so aliases work in non-interactive
  shells too (`BASH_ENV=~/.sh/_shrc bash -c 'alias'` works; the `sx` function
  relies on remote `bash -ci`).

## Core Variables (set by `_shrc`)

| Variable | Value |
|----------|-------|
| `OSTYP` | `alpine` `debian` `ubuntu` `cachyos` `manjaro` `arch` `openwrt` `macos` — from `/etc/os-release` `ID`, falling back to `ID_LIKE` (`*debian*`→debian, `*arch*`→arch), `/etc/openwrt_release`, `uname -s` (darwin→macos), else raw `uname -s` |
| `ARCH` | `x86_64` `arm64` `armv7`, else raw `uname -m` |
| `SUDO` | `/usr/bin/sudo ` (trailing space!) if UID > 0, empty for root. Used as unquoted prefix inside aliases |
| `COLOR` | Prompt ANSI colour, default `31` (red); override in `~/.myrc` |
| `LABEL` | Prompt label, default hostname; override in `~/.myrc` |
| `PS1` | `\[\033[1;${COLOR}m\]${LABEL} \w\[\033[0m\] ` |

## OS Abstraction

All conditional logic branches on `$OSTYP`. The same alias names map to
different backends:

| Alias | Purpose | openwrt | alpine | arch family | macos | debian family (else) |
|-------|---------|---------|--------|-------------|-------|----------------------|
| `i` | install | opkg install | apk add | paru -S | brew install | apt-get install |
| `r` | remove | opkg remove | apk del | paru -Rns | brew uninstall | apt-get remove --purge |
| `s` | search | opkg list | apk search -v | paru -Ss | brew search | apt-cache search |
| `u` | upgrade | opkg update+upgrade | apk update+upgrade | pacman -Syu (repos only) | brew update+upgrade | full apt dist-upgrade+autoremove+clean |
| `lspkg` | list installed | opkg list-installed | apk info | paru -Qs | brew list | dpkg --get-selections |
| `l` | follow syslog | logread -f | tail messages | journalctl -f | log stream | journalctl -f |

Arch family extras: `ua` (AUR only), `uu` (everything), `uc` (everything +
cache clean). macOS extra: `uc` (upgrade + cleanup); brew is **never** run
with sudo. `sc` (service control) wraps systemctl / OpenRC `rc-service` /
`/etc/init.d/` / launchctl; no args = list running services; Alpine converts
`@` in service names to `.`; OpenWRT also gets a `getent` shim.

## sshm Command Map

Dispatch is the `case` at `sshm:711`. Shortcuts: `i`=init `s`=sync `c`=create
`r`=read `u`=update `d`=delete `l`=list `t`=test `p`=perms `kc/kr/kd/kl`=key
ops, `pull` `push` `start` `stop` `h`/`ha`=help. Full help text lives in the
`help()` heredoc at `sshm:24` — keep it in sync with behaviour changes.

Behaviour not obvious from the help text:

- `create NAME IP [PORT] [USER] [KEYFILE]` writes a plain ssh_config block to
  `~/.ssh/hosts/NAME` (defaults: 22, root, `~/.ssh/keys/default`); the
  generated `~/.ssh/config` has `Include ~/.ssh/hosts/*` plus ControlMaster
  multiplexing (`~/.ssh/mux/%r@%h:%p`, persist 10m).
- `test` uses `ssh BatchMode=yes` with a 5s timeout, colour-coded summary,
  exit 1 if any non-ephemeral host failed. Hosts listed in
  `~/.ssh/hosts/.ephemeral` (one name per line, `#` comments) report
  `OFFLINE` instead of `FAILED` and survive `--delete-failed`. `github.com`
  is a built-in special host — `Permission denied (publickey)` counts as
  success (git providers don't give shells).
- `key_create` is Ed25519 only, `-a 100` KDF rounds, default comment
  `$(hostname)@lan`, refuses to overwrite.
- `pull` is fast-forward only; `push [MESSAGE]` auto-generates a message from
  changed file names if omitted, and pushes existing unpushed commits even
  when there's nothing new to commit.
- `init` is idempotent: existing `~/.bashrc` just gets the `_shrc` source
  line appended if missing; existing files are never overwritten.
- `sync HOST` rsyncs `~/.sh/` (excluding `.git`) then runs `sshm init`
  remotely; `~/.myrc` lives outside the repo so it is never synced.
- **NetServa class roster** `~/.ssh/hosts/.class` (`host class` pairs,
  unlisted = 3.0, `#` comments; template created by `init`). `host_class()`
  reads it; `sync` refuses class ≥ 4.0 hosts (NS 4.0/5.0 are mix-managed via
  `~/.mixrc`, and remote bash-isms misbehave against a mix login shell);
  `list` appends the class as a final column. No override flag — fix the
  roster entry instead.
- `stop` disables sshd **and** `pkill -9 sshd` — kills the current session if
  run over SSH.
- `sshm` sources `_shrc` at startup (`sshm:22`) so it has `OSTYP`/`SUDO`.

## Validation

```bash
bash -n _shrc && bash -n sshm                      # Syntax check core
for f in _shrc.d/*.sh; do bash -n "$f"; done       # Syntax check modules
source _shrc && echo "$OSTYP/$ARCH"                # Load check
sshm init                                          # Idempotent setup
sshm test                                          # SSH connectivity check
```

There is no test suite — `bash -n` plus sourcing plus an idempotent
`sshm init` run is the gate. This machine is CachyOS, so the arch-family
branches are what you can exercise live.

## Conventions

- **Bash required** — `_shrc` refuses non-bash shells at load time with an
  install hint (`_shrc:10`). Keep everything bash-compatible ≥ 3.2 except
  `sshm test`, which needs bash ≥ 4 (associative arrays; macOS needs
  `brew install bash`).
- **Single tool** — all management goes through `sshm`; don't add sibling
  scripts.
- **Idempotent** — `sshm init` and `sshm perms` must stay safe to repeat.
- **Ed25519 only** for SSH keys.
- **No Docker** — Incus containers or Proxmox VMs.
- **Core vs modules** — `_shrc` must stay safe to load on every platform;
  server-only functionality goes in `_shrc.d/` and is opted into via
  `~/.myrc`. New per-OS behaviour branches on `$OSTYP`, never on package
  manager probing.
- **Everything versioned** — no `.gitignore` exclusions; personal/secret
  config lives in `~/.myrc` outside the repo.
- **Underscore prefix** = special-use non-code files (`_shrc`, `_shrc.d/`,
  `_journal/`, templates). `docs/` is reserved for GitHub Pages — don't put
  project docs there.
- **Platforms** — Debian/Ubuntu, Arch/CachyOS/Manjaro, Alpine, OpenWRT,
  macOS (Homebrew + launchctl).

## Sharp Edges

- `$SUDO` is expanded **unquoted with a trailing space** inside alias
  definitions like `alias i=$SUDO'apt-get install'` — preserve that pattern
  exactly; quoting it breaks root (empty) vs non-root expansion.
- `_shrc`'s PATH reset (`_shrc:356`) intentionally starts with
  `/opt/cosmix/bin` (Cosmix daemons + mix shell, mirrors
  `/etc/profile.d/cosmix.sh`); don't remove it.
- The `?` alias (`bash ~/.help`) shadows the bash glob character in
  interactive use — deliberate.
- `sshm` runs with `set` defaults (no `-e`); several host/key commands
  `exit 254/255` on missing files — callers rely on those codes.
- `README.md` and `CLAUDE.md` are separate documents with different
  audiences. Never re-create the old `README.md → CLAUDE.md` symlink.

## License

Copyright (C) 1995-2026 Mark Constable <mc@netserva.org> (MIT License)
