# SH — Shell Configuration Toolkit

A small, bash-exclusive shell environment for people who administer more than
one machine. Clone it to `~/.sh`, run one command, and every box you touch —
Debian, Ubuntu, Arch, CachyOS, Manjaro, Alpine, OpenWRT or macOS — gets the
same aliases, the same functions, the same prompt and the same muscle memory,
while the toolkit quietly translates each command to whatever that OS actually
uses underneath.

It is three things in one repo:

1. **`_shrc`** — the core shell config: OS detection, ~60 aliases, a dozen
   admin functions, a coloured prompt.
2. **`sshm`** — the single management tool: bootstraps a machine, manages SSH
   hosts and keys, tests connectivity, deploys `~/.sh` to remote servers, and
   keeps itself updated via git.
3. **`_shrc.d/`** — optional server modules (mail/DKIM, logs, network
   diagnostics) that you opt into per machine.

Nothing here is magic: it is plain, readable bash. This manual starts at
"what happens when I open a terminal" and works down to the obscure corners.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Understanding SH — the mental model](#2-understanding-sh--the-mental-model)
3. [Installation](#3-installation)
4. [How Your Shell Loads SH — the bash source flow](#4-how-your-shell-loads-sh--the-bash-source-flow)
5. [Environment Variables](#5-environment-variables)
6. [Everyday Aliases](#6-everyday-aliases)
7. [Package Management — one interface, five backends](#7-package-management--one-interface-five-backends)
8. [Service Control — the sc wrapper](#8-service-control--the-sc-wrapper)
9. [Monitoring and Diagnostics](#9-monitoring-and-diagnostics)
10. [Notes, Help and Menu](#10-notes-help-and-menu)
11. [Functions Reference](#11-functions-reference)
12. [Personalising with ~/.myrc and the es alias](#12-personalising-with-myrc-and-the-es-alias)
13. [Server Modules (_shrc.d)](#13-server-modules-_shrcd)
14. [sshm — the SSH Manager](#14-sshm--the-ssh-manager)
15. [The ~/.ssh Layout sshm Creates](#15-the-ssh-layout-sshm-creates)
16. [Deploying SH to Remote Servers](#16-deploying-sh-to-remote-servers)
17. [Keeping SH Updated — sshm pull and push](#17-keeping-sh-updated--sshm-pull-and-push)
18. [Advanced and Obscure Topics](#18-advanced-and-obscure-topics)
19. [Troubleshooting](#19-troubleshooting)
20. [Uninstalling](#20-uninstalling)
21. [License](#21-license)

---

## 1. Quick Start

```bash
git clone https://github.com/markc/sh ~/.sh
~/.sh/sshm init          # set up this machine (shell + SSH structure)
source ~/.bashrc         # activate in the current terminal
```

Then try:

```bash
health                   # full system health report
sshm create web 10.0.0.5 # save a server by nickname
ssh web                  # connect to it
sshm sync web            # deploy this same toolkit to it
```

That is the whole product. Everything below explains what those commands
actually did and what else is in the box.

---

## 2. Understanding SH — the mental model

### The pieces

| Path | What it is | Who owns it |
|------|-----------|-------------|
| `~/.sh/` | This git repo — the toolkit itself. Identical on every machine | git (shared) |
| `~/.sh/_shrc` | The core config file your `~/.bashrc` sources | git (shared) |
| `~/.sh/_shrc.d/` | Optional server modules, loaded only if you ask | git (shared) |
| `~/.sh/sshm` | The management tool | git (shared) |
| `~/.myrc` | **Your** machine-local config: overrides, secrets, module opt-ins | you (this machine only, never synced, never versioned) |
| `~/.bashrc`, `~/.bash_profile` | Tiny stubs that hand control to `_shrc` | you (created from templates by `sshm init`) |

The design rule behind everything: **the repo is shared and generic; the
machine-specific bits live in one file, `~/.myrc`, outside the repo.** That is
why you can `git pull` (or `sshm pull`) on twenty servers without ever having
a merge conflict with local customisation, and why `sshm sync` can blast
`~/.sh` at a remote host without stomping on that host's personality.

### Why bash-only?

`_shrc` uses bash features (arrays, `[[ ]]`, `shopt`, associative arrays in
`sshm test`) and refuses to load under ash, dash or plain sh:

```
~/.sh/_shrc requires bash (install with: apk add bash / opkg install bash)
```

On Alpine and OpenWRT, bash is one package away (`apk add bash` /
`opkg install bash`). On macOS the system `/bin/bash` is ancient (3.2) but
still fine for everything except `sshm test` — see
[Advanced Topics](#18-advanced-and-obscure-topics).

### Why one tool?

There is deliberately no scattering of helper scripts. `sshm` does setup,
hosts, keys, deploy, git and sshd control, and `sshm ha` prints the complete
built-in help. If you remember one command, remember that one.

---

## 3. Installation

### Requirements

- **bash** (any version for the shell config; ≥ 4 for `sshm test`)
- **git** (to clone and update)
- **rsync** (only needed for `sshm sync` deploys)
- **ssh / ssh-keygen** (OpenSSH client, for the SSH management features)

### Fresh machine

```bash
git clone https://github.com/markc/sh ~/.sh
~/.sh/sshm init
source ~/.bashrc
```

`sshm init` is **idempotent** — run it as many times as you like. It does two
jobs:

**Shell init** — creates these *only if missing*:

- `~/.bash_profile` from `~/.sh/_bash_profile` (sources `/etc/profile`, then
  `~/.bashrc`)
- `~/.bashrc` from `~/.sh/_bashrc` (one line: source `~/.sh/_shrc`)
- `~/.myrc` from `~/.sh/_myrc.example` (your personal config)

If you **already have** a `~/.bashrc`, it is not replaced — `sshm init` just
appends the source line to it (once):

```bash
# Source SH shell enhancements
[[ -f ~/.sh/_shrc ]] && source ~/.sh/_shrc
```

**SSH init** — creates the NetServa-style `~/.ssh` structure (`hosts/`,
`keys/`, `mux/`, a `config` with sane defaults) and fixes permissions. Fully
described in [section 15](#15-the-ssh-layout-sshm-creates).

### Alpine / OpenWRT

Install bash first, then proceed as above:

```bash
apk add bash git          # Alpine
opkg install bash git     # OpenWRT
```

### macOS

Works out of the box with the system bash for daily use. For `sshm test`
(and a generally nicer life): `brew install bash`. Homebrew is **never** run
with sudo — the package aliases respect that.

### Remote servers

You do not repeat this procedure on servers — you deploy from your
workstation instead. See [section 16](#16-deploying-sh-to-remote-servers).

---

## 4. How Your Shell Loads SH — the bash source flow

Understanding this chain explains every "why did my setting (not) apply?"
question, so here it is end to end.

### Login shells (console, `ssh host`)

```
bash --login
  └── ~/.bash_profile          (template: _bash_profile)
        ├── /etc/profile       (system-wide defaults, if present)
        └── ~/.bashrc          (template: _bashrc)
              └── ~/.sh/_shrc  (the toolkit core)
                    └── ~/.myrc            (your machine-local config)
                          └── ~/.sh/_shrc.d/*.sh   (only what YOU source)
```

### Interactive non-login shells (a new terminal tab)

Same chain minus the first hop — bash reads `~/.bashrc` directly.

### What `_shrc` does, in order

The order matters and is worth knowing:

1. **Bash guard** — bail out loudly if not running under bash.
2. **`shopt -s expand_aliases`** — makes aliases work even in
   *non-interactive* bash (so `BASH_ENV=~/.sh/_shrc bash -c 'la'` and the
   `sx` remote helper work).
3. **OS detection** — sets and exports `OSTYP` and `ARCH`
   ([section 5](#5-environment-variables)).
4. **`SUDO`** — set to `/usr/bin/sudo ` if you are not root, empty if you
   are. Aliases are written as `alias i=$SUDO'apt-get install'`, so the same
   alias works for root and non-root users.
5. **All aliases** — universal ones first, then a per-OS block chosen by
   `$OSTYP` (packages, logs, monitoring).
6. **All functions** — `f`, `sc`, `sx`, `health`, `newpw`, etc.
7. **PATH baseline** — PATH is *reset* to a fixed, known-good value:
   ```
   /opt/cosmix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   ```
   This is deliberate (reproducible environment on every host) and it means
   any PATH additions **must** happen after this point — i.e. in `~/.myrc`.
8. **`COLOR` / `LABEL` defaults** — red prompt, hostname label.
9. **`source ~/.myrc`** — your file. Because it loads *after* the aliases and
   functions, it can override any of them; because it loads *before* the
   prompt is built, its `COLOR`/`LABEL` values win.
10. **Prompt** — `PS1` is assembled from `COLOR` and `LABEL`.
11. **`~/.sh` prepended to PATH** — this is what makes `sshm` callable as a
    bare command.

### The takeaway

- Change something for **every machine** → edit the repo (`~/.sh/…`), commit
  with `sshm push`.
- Change something for **this machine** → edit `~/.myrc` with the `es` alias
  ([section 12](#12-personalising-with-myrc-and-the-es-alias)).
- PATH additions go in `~/.myrc`, never earlier — `_shrc` would wipe them.

---

## 5. Environment Variables

`_shrc` exports these; your own scripts can branch on them too.

| Variable | Default / values | Meaning |
|----------|------------------|---------|
| `OSTYP` | `alpine` `debian` `ubuntu` `cachyos` `manjaro` `arch` `openwrt` `macos` | Detected OS family. Everything OS-specific in the toolkit branches on this |
| `ARCH` | `x86_64` `arm64` `armv7` (else raw `uname -m`) | Detected CPU architecture |
| `SUDO` | `/usr/bin/sudo ` or empty | Sudo prefix — empty when you *are* root, so the same aliases work everywhere |
| `COLOR` | `31` (red) | ANSI colour code for the prompt; override in `~/.myrc` |
| `LABEL` | hostname | The prompt label; override in `~/.myrc` |
| `PATH` | fixed baseline + `~/.sh` + your `~/.myrc` additions | See load order above |
| `PS1` | `LABEL \w ` in bold `COLOR` | The prompt itself |

### How OS detection works (in case it guesses wrong)

1. If `/etc/os-release` exists, its `ID` is matched against the known list.
2. Unknown `ID`? Fall back to `ID_LIKE`: anything `*debian*` becomes
   `debian`, anything `*arch*` becomes `arch` — so most derivatives Just
   Work.
3. `/etc/openwrt_release` → `openwrt`; `uname -s` = darwin → `macos`.
4. Otherwise `OSTYP` is the raw lowercase `uname -s` and you get the
   Debian-flavoured defaults (the `else` branch).

Check what was detected any time with `echo $OSTYP/$ARCH`.

Useful ANSI colours for `COLOR`: 31 red, 32 green, 33 yellow, 34 blue,
35 magenta, 36 cyan. A common convention: red for production, green for
workstations, yellow for staging — set per machine in `~/.myrc`.

---

## 6. Everyday Aliases

### Navigation and files

| Alias | Expands to | Notes |
|-------|-----------|-------|
| `..` | `cd ..` | |
| `ls` | `ls -F --group-directories-first --color` | directories first, type suffixes |
| `ll` | `ls -lF --group-directories-first --color` | long listing |
| `la` | `ls -lFAh --group-directories-first --color` | long, all files, human sizes |
| `df` | `df -kTh` | filesystem type + human sizes |

All three `ls` variants set `LC_COLLATE=C` so dotfiles sort predictably
(ASCII order) regardless of locale.

### Editors

| Alias | Expands to | Notes |
|-------|-----------|-------|
| `e FILE` | `nano -t -x -c` | nano: no prompt-on-save, no help bar, show cursor position |
| `se FILE` | `sudo nano -t -x -c` | same, as root |

### Search

| Alias/Fn | Usage | What it does |
|----------|-------|--------------|
| `f PATTERN` | `f myrc` | find files by name (case-insensitive substring) under the current directory, with `-ls` detail |
| `q PATTERN` | `q "TODO"` | recursive grep through all files under the current directory (null-safe via `find -print0 \| xargs -0`) |
| `p PATTERN` | `p nginx` | grep the process list (grep itself filtered out) |

### Miscellaneous

| Alias | What it does |
|-------|--------------|
| `ff` | `fastfetch --logo none` — quick system summary |
| `wt URL` | curl the URL, print only the total transfer time — a one-shot web timing probe |
| `shortname` | prints `n` + the last 5 hex digits of the first ethernet MAC — a stable, unique short host ID, handy for naming machines |

---

## 7. Package Management — one interface, five backends

The flagship feature. The same five keystrokes manage packages on every OS;
`_shrc` picks the backend from `$OSTYP` and bakes `$SUDO` in, so the alias is
identical whether you are root or not.

| Alias | Meaning | Debian/Ubuntu | Arch/CachyOS/Manjaro | Alpine | OpenWRT | macOS |
|-------|---------|---------------|----------------------|--------|---------|-------|
| `i PKG` | install | `apt-get install` | `paru -S` | `apk add` | `opkg install` | `brew install` |
| `r PKG` | remove | `apt-get remove --purge` | `paru -Rns` | `apk del` | `opkg remove` | `brew uninstall` |
| `s WORD` | search | `apt-cache search` | `paru -Ss` | `apk search -v` | `opkg list \| grep` | `brew search` |
| `u` | upgrade | full `dist-upgrade` + autoremove + clean | `pacman -Syu` (**official repos only**) | `apk update && apk upgrade` | `opkg update` + upgrade all | `brew update && brew upgrade` |
| `lspkg WORD` | list installed matching | `dpkg --get-selections \| grep` | `paru -Qs` | `apk info \| grep` | `opkg list-installed \| grep` | `brew list \| grep` |
| `edpkg` | edit the repo/source config | `sources.list` | `pacman.conf` | `repositories` | `customfeeds.conf` | `Brewfile` |

### Arch-family upgrade tiers

On Arch/CachyOS/Manjaro, upgrades are split so you control how much churn you
take on:

| Alias | Scope |
|-------|-------|
| `u` | official repos only (`pacman -Syu`) |
| `ua` | AUR packages only (`paru -Sua`) |
| `uu` | everything — repos + AUR (`paru -Syu`) |
| `uc` | everything **plus** cache cleanup and orphan removal |

All are `--noconfirm --skipreview` — these are "just do it" commands.

### macOS notes

`uc` = update + upgrade + `brew cleanup`. Homebrew refuses to run as root, so
none of the macOS package aliases use `$SUDO` — correct behaviour, not an
omission.

---

## 8. Service Control — the sc wrapper

`sc` gives you one verb set across systemd, OpenRC, SysV init and launchctl:

```bash
sc                        # list services (running ones, or all on some OSes)
sc status nginx
sc start nginx
sc stop nginx
sc restart nginx
sc reload opendkim        # OpenWRT/Alpine/systemd
sc enable nginx           # start at boot
sc disable nginx
```

Backends per OS:

| OSTYP | Backend | Quirks |
|-------|---------|--------|
| debian/ubuntu/arch family (default) | `systemctl` | `sc` with no args lists running services, names cleaned of `.service` |
| alpine | `rc-service` / `rc-update` | `enable`/`disable` add/remove from the `default` runlevel; an `@` in a service name is converted to `.` |
| openwrt | `/etc/init.d/NAME verb` | no-args lists `/etc/init.d/` |
| macos | `launchctl` | `enable`/`disable` are `load -w`/`unload -w` (expect a plist path); `restart` is stop-then-start |

Related aliases: `services` (running services), `failed` (failed units) —
see the next section.

---

## 9. Monitoring and Diagnostics

### The one to remember

```bash
health
```

Prints a full report: date, uptime, load, memory, disk, top CPU processes,
listening-port count, and SSH failed-login attempts in the last hour. It
degrades gracefully — every section has fallbacks for systems without
`free`, `journalctl`, or GNU `ps`.

### The rest of the kit

| Alias | Linux backend | macOS backend | Shows |
|-------|---------------|---------------|-------|
| `ports` | `ss -tuln` | `lsof -iTCP -sTCP:LISTEN` | listening sockets |
| `procs` | `ps aux --sort=-%cpu \| head -20` | `ps -Ao … -r` | top processes by CPU |
| `mem` | `free -h` | `top -l1` PhysMem line | memory usage |
| `ram` | per-OS `ps` sorted by RSS | `ps -Ao rss,… -r` | processes by memory |
| `disk` | `df -h` | same | disk usage |
| `temp` | `sensors`, falling back to `/sys/class/thermal` | — | temperatures |
| `sysinfo` | uname + uptime + mem + `df /` | same idea | one-screen summary |
| `logs` | `journalctl -f` | `log stream` | live system log |
| `l` | same as `logs` (per-OS: `logread -f` on OpenWRT, `tail /var/log/messages` on Alpine) | `log stream` | shortest possible log follow |
| `syslog` | `tail -f /var/log/syslog` → `messages` → `journalctl -f` | `log stream` | classic syslog, with fallbacks |
| `authlog` | `tail -f /var/log/auth.log` → `journalctl -u ssh` | authd predicate stream | authentication log |
| `services` | `systemctl list-units --type=service --state=running` | `launchctl list` | running services |
| `failed` | `systemctl list-units --failed` | non-zero-exit launchctl jobs | failed services |
| `failedlogins` | `journalctl -t sshd \| grep "Failed password"` | sshd log predicate | recent brute-force attempts |
| `lastlog` | `last \| head -10` | same | recent logins |

And two function-based tools:

```bash
pstree_service nginx      # process tree for a service (systemd MainPID aware)
wt https://example.com    # response time for a URL
```

---

## 10. Notes, Help and Menu

A tiny personal knowledge system built on three plain files in your home
directory (all optional, all machine-local):

| Alias | File | What it does |
|-------|------|--------------|
| `n` | `~/.note` | appends a timestamp header, then opens the file in nano at the end — a frictionless "jot this down now" |
| `sn` | `~/.note` | show (cat) all notes |
| `?` | `~/.help` | *runs* `~/.help` as a bash script — put echo lines or a case statement in it; it's your personal cheat-sheet command |
| `eh` | `~/.help` | edit the help/cheat-sheet file |
| `m` | `~/.menu` | runs `~/.menu` as a bash script — build yourself an interactive admin menu if you like |
| `es` | `~/.myrc` | edit personal config and hot-reload the whole toolkit — see [section 12](#12-personalising-with-myrc-and-the-es-alias) |

Yes, `?` is a valid alias name in bash, and yes, it shadows the single-char
glob in interactive use. If you actually need a glob matching one character,
use `[!/]` or just don't name files that way.

---

## 11. Functions Reference

Full reference for the functions `_shrc` defines. (Package/service wrappers
were covered above.)

### `f PATTERN` — find files by name

```bash
f config          # every file with "config" in its name, from . down
```

Case-insensitive substring match, with `-ls` output (permissions, size,
date). On OpenWRT (BusyBox find) it drops `-ls`.

### `sx HOST COMMAND…` — run a command in a remote *interactive* bash

```bash
sx web "la /etc/nginx"
sx web u                    # yes: run the remote's own package-upgrade alias
```

The point: a plain `ssh host cmd` runs a non-interactive shell with **no
aliases and no ~/.bashrc**, so none of the SH goodies exist there. `sx`
instead runs `bash -ci '<command>'` on the remote — a full interactive shell
with the remote's `_shrc` and `~/.myrc` loaded — and then strips the
"cannot set terminal process group" / "no job control" noise that
interactive-without-a-tty bash prints. Result: your aliases work on the
remote, output stays clean.

Arguments are `printf '%q'`-quoted, so spaces and quotes survive the trip.

### `health` — system health report

See [section 9](#9-monitoring-and-diagnostics).

### `newpw [LENGTH]` — generate a password

```bash
newpw             # 16 chars
newpw 32          # 32 chars
```

Pulls from `/dev/urandom`, **guarantees** at least one uppercase, one
lowercase and one digit, shuffles the result, and maps `O`/`o` to `0` to
avoid the classic ambiguous-glyph transcription error.

### `chktime FILE SECONDS` — is a file older than N seconds?

```bash
chktime /tmp/cache.json 3600 && echo "stale, refresh it"
```

Returns success (0) when the file's timestamp plus N seconds is in the past.
Designed for cheap cache-invalidation logic in scripts.

### `getusers` / `grepuser NAME` — human account queries

```bash
getusers          # all accounts with UID 1000–9998 (real people, not system)
grepuser mark     # find a specific one
```

Works via `getent passwd`; on OpenWRT (no getent) `_shrc` installs a tiny
shim that reads `/etc/passwd` directly.

### `pstree_service SERVICE` — process tree for a service

Resolves the service's MainPID via systemd when available (falls back to
`pgrep`), then shows `pstree -p` (or a `ps --forest` fallback).

### `sc` — service control

See [section 8](#8-service-control--the-sc-wrapper).

---

## 12. Personalising with ~/.myrc and the es alias

`~/.myrc` is **your** file: machine-local, never committed, never synced by
`sshm sync`. It is sourced by `_shrc` on every shell start, *after* all the
toolkit's aliases and functions (so it can override anything) and *before*
the prompt is built (so `COLOR`/`LABEL` take effect).

### The workflow: `es`

```bash
es
```

does three things: opens `~/.myrc` in nano, re-sources `~/.sh/_shrc` the
moment you save-and-exit (which in turn re-sources your fresh `~/.myrc`), and
confirms:

```
✅ Reloaded: _shrc → _myrc
```

So the loop is: `es` → edit → save → your change is live in the current
shell. No logout, no new terminal, no manually remembering the source
command. This is the single most-used customisation habit in the toolkit.

### What to put in it

```bash
# ~/.myrc — this machine only

# Prompt: yellow, custom label (defaults: 31/red, hostname)
COLOR=33
LABEL=staging-db

# Machine-local PATH additions (must be here — _shrc resets PATH earlier)
PATH="$HOME/bin:$PATH"

# Secrets that must never enter a git repo
export RESTIC_PASSWORD_FILE=~/.restic-pw
export HCLOUD_TOKEN=…

# Personal aliases / overrides (loaded after _shrc, so overrides win)
alias vps='ssh myvps'
alias u='paru -Syu'          # e.g. re-tame the upgrade alias on this box

# Opt into server modules on this machine (see section 13)
source ~/.sh/_shrc.d/server.sh
source ~/.sh/_shrc.d/logs.sh
source ~/.sh/_shrc.d/net.sh
```

The shipped template (`_myrc.example`, copied on first `sshm init`) contains
one line worth keeping:

```bash
alias sshm=~/.sh/sshm
```

— a belt-and-braces alias so `sshm` works even in a shell where `~/.sh`
didn't make it onto PATH.

### The rule of thumb

| Change | Where it goes |
|--------|---------------|
| Useful on every machine | the repo — edit `~/.sh/_shrc` (or a module), `sshm push` |
| Only this machine (labels, tokens, module opt-ins, PATH) | `~/.myrc` via `es` |

---

## 13. Server Modules (_shrc.d)

The core `_shrc` stays lean and universal; anything server-flavoured lives in
`~/.sh/_shrc.d/*.sh` and loads **only** if your `~/.myrc` sources it. A
workstation never needs to see a DKIM function.

```bash
# in ~/.myrc, per machine, pick what applies:
source ~/.sh/_shrc.d/logs.sh
source ~/.sh/_shrc.d/net.sh
source ~/.sh/_shrc.d/server.sh
```

### logs.sh — mail/web/DNS log tails

| Alias | Follows |
|-------|---------|
| `mlog` | `/var/log/mail.log` |
| `mgrep PATTERN` | mail log filtered by pattern |
| `alog` | nginx access log |
| `elog` | nginx error log |
| `plog` | `../log/php-errors.log` (relative — meant to be run from inside a vhost dir, pairs with `go2`) |
| `dlog` | PowerDNS via `journalctl -u pdns -f` |
| `maillog` | live stream of mail **Subject:** headers, cleaned up — a delightful "what is the mail server chewing on right now" view |

### net.sh — network diagnostics and firewall

**`shwho DOMAIN`** — the domain triage one-shot: registrar, name servers and
DNSSEC from WHOIS, the A record(s), the MX host, its IP, and the reverse PTR
of that IP. One command answers "who runs this domain and where does its mail
go". Needs `whois` and `dig` installed (it tells you if they're missing).

**`shblock`** — lists the current attacker IPs in the `sshguard` nftables
set, one per line. The `oldblock` / `oldshblock` / `oldunblock` aliases are
the legacy iptables equivalents (manual block / list / unblock).

### server.sh — mail server and vhost administration

Assumes the NetServa-style layout (`/srv/DOMAIN/web/app`,
`/srv/DOMAIN/msg/USER`) and OpenDKIM at `/etc/opendkim/`.

**Vhost navigation**

```bash
go2 example.com           # cd /srv/example.com*/web/app
go2 user@example.com      # cd into that mailbox dir under msg/
shhost                    # list all vhosts in /srv/
shhost exam               # filter
```

**User management**

```bash
newuser bob                       # create user, auto-generate password (newpw)
newuser bob secret "Bob R" /home/bob
chrootuser bob                    # convert to chrooted SFTP: home root-owned,
                                  # ~/data/ writable — for backup-target accounts
```

**DKIM lifecycle** (2048-bit keys, default selector `mail`)

```bash
shdkim                    # list all domains with DKIM keys and their state
shdkim example.com        # print the DNS record name + value ready to paste
adddkim example.com       # generate key, wire up KeyTable/SigningTable/
                          # TrustedHosts, reload opendkim, print the TXT record
chdkim example.com        # rotate: back up old key, generate new, reload,
                          # print the new TXT record
deldkim example.com       # remove from all tables, archive the key dir
                          # (timestamped .deleted dir — nothing is destroyed)
```

All DKIM commands take an optional second `selector` argument. `adddkim` and
`chdkim` end by printing exactly the DNS TXT record you need to publish.

---

## 14. sshm — the SSH Manager

`sshm` is the toolkit's control surface. `sshm` alone (or `sshm h`) shows the
command summary; `sshm ha` prints the full built-in manual. Every command has
a short alias:

```
SETUP        i  = init        s  = sync
HOSTS        c  = create      r  = read       u = update
             d  = delete      l  = list        t = test
KEYS         kc = key_create  kr = key_read
             kd = key_delete  kl = key_list
GIT          pull             push
UTILS        p  = perms       start            stop
HELP         h  = help        ha = help all
```

### Host management — servers by nickname

Each saved host is one small ssh_config file in `~/.ssh/hosts/`, pulled in by
the `Include` line in `~/.ssh/config`. That means **plain `ssh NICKNAME`
works everywhere** — scp, rsync, git, anything that uses OpenSSH config picks
the nicknames up too.

```bash
sshm create web 10.0.0.5                 # port 22, user root, default key
sshm create db  10.0.0.6 2222 admin      # custom port and user
sshm create pi  192.168.1.50 22 pi ~/.ssh/keys/pi   # specific key
sshm list                                # table: name, IP, port, user, key
sshm read web                            # show one host's values
sshm update web                          # edit the host file in nano
sshm delete web                          # remove it
```

A created host file looks like:

```
Host web
  Hostname 10.0.0.5
  Port 22
  User root
  IdentityFile ~/.ssh/keys/default
```

`sshm update` just opens that in nano — add any OpenSSH option you like
(`ProxyJump`, `LocalForward`, …); `sshm` never rewrites your edits.

### Key management — Ed25519 only

```bash
sshm key_create                          # creates ~/.ssh/keys/default (+ .pub)
sshm key_create work "Laptop" "secret"   # named key, comment, passphrase
sshm key_list                            # all keys with fingerprints
sshm key_read                            # cat the default public key
sshm key_read work                       # …or a named one
sshm key_delete work                     # remove keypair (private + public)
```

Keys are Ed25519 with 100 KDF rounds (`ssh-keygen -o -a 100 -t ed25519`) —
modern, small, and expensive to brute-force if the private key file ever
leaks. Default comment is `<hostname>@lan`. `key_create` refuses to
overwrite an existing key.

The key named **`default`** is special only by convention: it's what
`sshm create` assigns when you don't specify a key. Get it onto a server
with:

```bash
ssh-copy-id -i ~/.ssh/keys/default.pub root@10.0.0.5
```

### Connectivity testing

```bash
sshm test                # test every saved host
sshm test web            # test one
sshm test --delete-failed   # test all, delete the dead ones
```

Each host gets a real `ssh` attempt with `BatchMode=yes` (never hangs on a
password prompt) and a 5-second timeout, then a colour-coded per-host line
and a summary. Exit status is 1 if any host failed — usable in scripts.

Two refinements worth knowing:

- **Git providers.** `github.com` is recognised as a special host: it never
  gives you a shell, so the usual "run `true` remotely" probe can't work.
  Instead, a successful-auth banner ("Hi <user>! You've successfully
  authenticated") **or** a clean `Permission denied (publickey)` both count
  as OK, because either proves the network path and SSH endpoint are alive.
- **Ephemeral hosts.** Laptops, VMs and other sometimes-off machines listed
  in `~/.ssh/hosts/.ephemeral` (one host name per line, `#` comments
  allowed) report **⏸ OFFLINE** instead of ❌ FAILED, don't fail the run, and
  are never removed by `--delete-failed`. This keeps `sshm test
  --delete-failed` safe to run as a periodic dead-host reaper without it
  eating your laptop's config.

### sshd service control (workstation convenience)

```bash
sshm start        # start sshd now, but do NOT enable at boot
sshm stop         # stop sshd, disable at boot, and kill existing sshd
                  # processes (drops all current connections)
```

Designed for the "I only want SSH into my workstation while I'm actively
using it" pattern. Both need sudo and assume systemd. **Careful:** `sshm
stop` includes a `pkill -9 sshd` — run it over SSH and you are sawing off
the branch you're sitting on.

### Utilities

```bash
sshm perms        # chmod 700 every dir / 600 every file under ~/.ssh
```

Run it after any rsync, restore or git operation that may have loosened
permissions — OpenSSH silently ignores keys and configs it deems too open,
which presents as mysterious "it stopped using my key" behaviour.

---

## 15. The ~/.ssh Layout sshm Creates

`sshm init` builds (only if missing):

```
~/.ssh/
├── config              # generated once — see below
├── authorized_keys
├── hosts/              # one file per saved host  (sshm create/…)
│   ├── .class          # optional: NetServa class roster (see section 16)
│   └── .ephemeral      # optional: names of sometimes-offline hosts
├── keys/               # your Ed25519 keypairs    (sshm key_create/…)
└── mux/                # live ControlMaster sockets (auto-managed)
```

The generated `~/.ssh/config`:

```
Ciphers aes128-ctr,…,chacha20-poly1305@openssh.com   # modern cipher set

Include ~/.ssh/hosts/*        # every saved host becomes a real ssh alias

Host *
  TCPKeepAlive yes
  ServerAliveInterval 30      # survive NAT/firewall idle timeouts
  ForwardAgent yes
  AddKeysToAgent yes
  IdentitiesOnly yes          # only offer the key the host file names
  ControlMaster auto          # multiplexing:
  ControlPath ~/.ssh/mux/%r@%h:%p
  ControlPersist 10m
```

Two of these earn their keep daily:

- **ControlMaster multiplexing** — the first connection to a host opens a
  socket in `mux/`; every subsequent `ssh`/`scp`/`rsync`/`git` to the same
  host for the next 10 minutes rides that socket and connects
  *instantly* (no new TCP+auth handshake). This is why repeated `sshm sync`
  and `sx` calls feel free.
- **IdentitiesOnly** — ssh offers *only* the key configured for that host
  instead of trying every key in your agent, which avoids the classic
  "Too many authentication failures" lockout when you accumulate keys.

It's created once and then it's yours — `sshm` never rewrites an existing
`~/.ssh/config`.

---

## 16. Deploying SH to Remote Servers

The two-command deploy:

```bash
sshm create web 10.0.0.5      # once: save the host
sshm sync web                 # any time: push the toolkit to it
```

`sync` does exactly two things:

1. `rsync -avz --exclude='.git' ~/.sh/ web:~/.sh/` — mirror the toolkit
   (without git history) to the remote.
2. `ssh web '~/.sh/sshm init'` — run the same idempotent bootstrap there,
   which wires up the remote's `~/.bashrc` and `~/.ssh` on first run and
   does nothing on later runs.

Properties that make this safe to run repeatedly:

- **`~/.myrc` is never touched** — it lives outside `~/.sh`, so each
  machine's personality (prompt colour, tokens, module opt-ins) survives
  every sync.
- Re-syncing an already-set-up host is a no-op apart from copying changed
  files.
- The remote needs bash and rsync; on Alpine/OpenWRT install those first
  (`i bash rsync`, once you're there — or `ssh web 'apk add bash rsync'` to
  get started).

Typical fleet update: edit something in `~/.sh`, then
`for h in web db mail; do sshm sync $h; done`.

Note the deploy is **push-based and git-free** on the servers — remotes get a
plain directory, not a git clone. Your workstation's clone is the source of
truth; git history stays with you.

### The NetServa class roster — ~/.ssh/hosts/.class

Not every server should get `~/.sh`. In NetServa terms, NS 1.0–3.0 machines
run bash and are managed by this toolkit; NS 4.0 (NS 3.0 + mix) and NS 5.0
(pure cosmix) machines run mix as the login shell with `~/.mixrc`, and are
managed by the mix/cosmix tooling instead. Deploying `~/.sh` to one of those
— and especially running `sshm init` over ssh against a mix login shell —
ranges from pointless to harmful.

`~/.ssh/hosts/.class` records which is which: one `host class` pair per
line, whitespace separated, blank lines and `#` comments ignored. Hosts not
listed default to **3.0**, so you only annotate the exceptions:

```
# ~/.ssh/hosts/.class
mko   5.0
web1  4.0
ns1gc 1.0
```

Two things read it:

- **`sshm sync` refuses any host whose class is 4.0 or higher**, with an
  error telling you why. There is no override flag — if the refusal is
  wrong, fix the roster entry.
- **`sshm list` shows the class** as a final column, so the fleet split is
  visible at a glance.

`sshm init` creates a commented template if the file is missing. Like
everything else in `~/.ssh`, the roster is machine-local — it names real
hosts, so it never belongs in a public repo.

---

## 17. Keeping SH Updated — sshm pull and push

Your workstation's `~/.sh` is a normal git clone, and `sshm` wraps the two
operations you actually need:

```bash
sshm pull                # fetch; report; fast-forward if upstream is newer
sshm push                # commit ALL changes + push (auto message)
sshm push "Add wt alias" # same, with your message
```

Details:

- `pull` is **fast-forward only** — it will never create a merge commit or
  rebase surprise. If you have local commits, it tells you to `sshm push`
  instead.
- `push` with no message auto-generates one from the changed file names
  (`Update: _shrc sshm …`). It also handles the "nothing changed but I have
  unpushed commits" case by just pushing.
- After updating, `source ~/.sh/_shrc` (or open a new terminal) to load the
  new code, then `sshm sync` any servers that should get it.

---

## 18. Advanced and Obscure Topics

The corners you only hit once you live in this thing.

### The PATH reset

`_shrc` **overwrites** PATH with a fixed baseline:

```
/opt/cosmix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

then appends your `~/.myrc` additions and finally prepends `~/.sh`. This
guarantees an identical, predictable PATH on every host (and always includes
sbin, which many distros omit for non-root users — so `ss`, `sysctl` etc.
work unqualified). The flip side: **anything that prepends to PATH before
`_shrc` runs is wiped**. Version managers (cargo, nvm, pyenv…) must be
activated from `~/.myrc`, not from earlier in `~/.bashrc`. (`/opt/cosmix/bin`
leads the baseline because that's where the Cosmix daemons and the mix shell
live on these machines; harmless if the directory doesn't exist.)

### Aliases in non-interactive shells

`_shrc` runs `shopt -s expand_aliases` up front, which is why its aliases
work in places bash normally disables them:

```bash
BASH_ENV=~/.sh/_shrc bash -c 'la /etc'    # aliases in a script context
```

and why `sx` works at all: `sx host cmd` runs `bash -ci 'cmd'` remotely — an
interactive shell, so the remote's full `_shrc` + `~/.myrc` load — then
filters out the two job-control warnings bash emits when interactive without
a real tty. If you ever wondered why `ssh host la` fails but `sx host la`
works, that's the whole story.

### $SUDO mechanics

`SUDO` is either `/usr/bin/sudo ` — note the **trailing space** — or empty.
Package aliases are defined as `alias i=$SUDO'apt-get install'`: at
definition time that concatenates into either `sudo apt-get install` or
`apt-get install`. One alias definition, correct for root and non-root, no
runtime branching. (This is also why `_shrc` does `unalias sudo` first — a
distro-supplied `sudo` alias would break the expansion.) Your own scripts can
reuse it: `$SUDO systemctl restart nginx`.

### OSTYP fallbacks and derivatives

An unlisted distro is not a failure: `ID_LIKE` matching means e.g. Pop!_OS,
Mint or Raspbian resolve to `debian` and EndeavourOS to `arch`, landing on
the right package aliases automatically. A totally unknown OS lands in the
`else` branch (Debian-style apt aliases) — worst case some aliases point at
missing binaries; nothing breaks at load time.

### Bash version requirements

- The shell config runs on **bash 3.2+** (so macOS system bash is fine for
  daily use).
- `sshm test` uses associative arrays → **bash ≥ 4**. On macOS:
  `brew install bash` (you don't need to chsh; `sshm` finds it via env
  once brew's bash is first in PATH).

### Ephemeral hosts file format

`~/.ssh/hosts/.ephemeral` — one host nickname per line, blank lines and `#`
comments ignored. Dotfiles in `hosts/` are skipped by the test scanner, so
the file itself is never "tested". Anything named here is expected to be
offline sometimes: reported `OFFLINE`, never deleted, never fails the run.

### Class roster file format

`~/.ssh/hosts/.class` — one `host class` pair per line (e.g. `mko 5.0`),
whitespace separated, blank lines and `#` comments ignored. Unlisted hosts
default to `3.0`. Classes `4.0`+ mark mix-managed machines: `sshm sync`
refuses them, `sshm list` shows the class column. See section 16.

### sshm exit codes

`sshm test` exits 1 when any non-ephemeral host fails (0 otherwise) —
cron-friendly. Host/key commands exit `254` for "doesn't exist / already
exists" notices and `255` for hard errors, so scripts can distinguish
"nothing to do" from "broken".

### The generated ssh config is a one-shot

`sshm init` writes `~/.ssh/config` **only if it doesn't exist**. If you want
the sshm-style config on a machine with an existing hand-rolled one, merge in
the `Include ~/.ssh/hosts/*` line yourself — that's the only line the host
commands actually depend on.

### Where the line counts stand

`_shrc` ~370 lines, `sshm` ~695, the three modules ~270 combined. The whole
toolkit is an evening's read — recommended, since it's your shell now.

### For AI-assisted maintenance

`CLAUDE.md` in this repo is a machine-oriented companion document for Claude
Code (file map, invariants, validation commands). It's not a user manual —
this file is. If you change behaviour, update both.

---

## 19. Troubleshooting

**"~/.sh/_shrc requires bash"** — your login shell is ash/dash/sh. Install
bash (`apk add bash` / `opkg install bash`) and either `chsh` to it or start
it manually; `_shrc` refuses non-bash shells on purpose.

**Aliases missing over `ssh host cmd`** — expected; non-interactive SSH
loads nothing. Use `sx host cmd` instead ([section 18](#18-advanced-and-obscure-topics)).

**My PATH addition disappears** — you added it before `_shrc` runs. Move it
to `~/.myrc` ([section 4](#4-how-your-shell-loads-sh--the-bash-source-flow)).

**SSH ignores my key after a restore/rsync** — permissions. Run
`sshm perms`.

**`sshm test` errors on macOS** — system bash is 3.2; `brew install bash`.

**Wrong package aliases on a niche distro** — check `echo $OSTYP`; if the
fallback guessed wrong, `export OSTYP=arch` (or whatever's right) in
`~/.myrc` *won't* help because detection runs first — instead redefine the
few aliases you need in `~/.myrc`, which loads last and wins.

**A stale ControlMaster socket makes ssh hang for one host** — remove the
socket: `rm ~/.ssh/mux/*@thathost*` (or `ssh -O exit thathost`).

**`sshm pull` refuses to update** — you have local commits or modifications;
it's fast-forward-only by design. `sshm push` first (or stash).

---

## 20. Uninstalling

SH keeps a light footprint, so removal is short:

```bash
rm -rf ~/.sh                       # the toolkit
rm ~/.myrc                         # your personal config (keep if unsure!)
nano ~/.bashrc                     # delete the "source ~/.sh/_shrc" line
```

`~/.ssh` is yours, not the toolkit's — everything in it (hosts, keys, config)
keeps working with plain OpenSSH after SH is gone, which is exactly why sshm
stores things as standard ssh_config files rather than in its own database.

---

## 21. License

Copyright (C) 1995-2026 Mark Constable <mc@netserva.org> (MIT License)
