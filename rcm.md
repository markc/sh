# rcm(1) - RC Manager

## NAME

rcm - Manage RC shell configuration deployment

## SYNOPSIS

```bash
rcm init                 # Initialize shell config on current machine
rcm sync <ssh_host>      # Sync ~/.rc to remote server
rcm help [command]       # Show help
```

## DESCRIPTION

Manages deployment of the RC shell configuration system. Use `rcm init` to set up the current machine, or `rcm sync` to deploy `~/.rc/` to remote servers.

Requires bash. On Alpine: `apk add bash`. On OpenWRT: `opkg install bash`.

## COMMANDS

### init

```bash
rcm init
```

Creates from templates (if missing):
- `~/.bash_profile` from `_bash_profile`
- `~/.bashrc` from `_bashrc` (or appends source line to existing)
- `~/.myrc` from `_myrc.example`

**Safe to run multiple times.**

### sync

```bash
rcm sync <ssh_host>
```

Uses rsync to sync `~/.rc/` (excluding `.git`) to remote, then runs `rcm init` on the remote.

Note: `~/.myrc` is never synced — each machine has its own.

## FILES

- `~/.rc/_shrc` - Core shell toolkit (synced to remotes)
- `~/.rc/_shrc.d/` - Optional server modules (synced, loaded via ~/.myrc)
- `~/.myrc` - Personal config (machine-local, never synced)

## EXAMPLES

### Initial Setup

```bash
git clone https://github.com/markc/rc ~/.rc
rcm init
source ~/.bashrc
```

### Deploy to Remote

```bash
sshm create server1 10.0.0.5
rcm sync server1
```

### Customize

```bash
es    # Edit ~/.myrc and reload
```

## SEE ALSO

- `CLAUDE.md` - Architecture and usage reference
- `sshm.md` - SSH host/key management

## AUTHOR

Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License)
