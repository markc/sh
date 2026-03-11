# sshm(1) - SSH Manager

## NAME

sshm - Manage SSH host configurations and keys

## SYNOPSIS

```bash
# Host Management
sshm create <name> <host> [port] [user] [key]
sshm read <name>
sshm update <name>
sshm delete <name>
sshm list
sshm test [name] [--delete-failed]

# Key Management
sshm key_create <name> [comment] [passphrase]
sshm key_read <name>
sshm key_delete <name>
sshm key_list

# Utilities
sshm init
sshm perms

# Service (sudo)
sshm start
sshm stop
```

## DESCRIPTION

Manages SSH using NetServa 3.0 directory structure with individual host files:

```
~/.ssh/
├── config              # Main config (includes hosts/*)
├── authorized_keys     # Public keys
├── hosts/              # Individual host configs
├── keys/               # Ed25519 keypairs
└── mux/                # ControlMaster multiplexing sockets
```

## HOST COMMANDS

### create

```bash
sshm create server1 192.168.1.100
sshm create server2 192.168.1.101 2222 admin ~/.ssh/keys/mykey
```

Creates `~/.ssh/hosts/<name>` with Host, Hostname, Port, User, IdentityFile.
Defaults: port 22, user root.

### read

```bash
sshm read server1
```

Display host configuration values.

### update

```bash
sshm update server1
```

Edit `~/.ssh/hosts/<name>` in nano.

### delete

```bash
sshm delete server1
```

Remove host configuration file.

### list

```bash
sshm list
```

Show all hosts with hostname, port, user, and key path.

### test

```bash
sshm test                    # Test all hosts
sshm test server1            # Test specific host
sshm test --delete-failed    # Test all, delete unreachable
```

Tests TCP connectivity with 5-second timeout. Supports ephemeral hosts
(listed in `~/.ssh/hosts/.ephemeral`) which show as "offline" rather than
"failed". Git providers (github.com) are detected automatically.

## KEY COMMANDS

### key_create

```bash
sshm key_create mykey
sshm key_create work "Laptop" "passphrase123"
```

Creates Ed25519 keypair in `~/.ssh/keys/` with 100 KDF rounds.

### key_read

```bash
sshm key_read mykey
```

Display public key (for copying to servers).

### key_delete

```bash
sshm key_delete mykey
```

Remove private and public key files.

### key_list

```bash
sshm key_list
```

List all keys with fingerprints.

## UTILITY COMMANDS

### init

```bash
sshm init
```

Creates NS 3.0 directory structure and generates `~/.ssh/config` with:
- Secure ciphers only
- Connection multiplexing (ControlMaster auto, 10min persist)
- Keep-alive (ServerAliveInterval 30s)
- ForwardAgent and AddKeysToAgent enabled

Safe to run multiple times.

### perms

```bash
sshm perms
```

Fixes all SSH permissions: directories 700, files 600.
Use after git clone or rsync.

### start

```bash
sshm start
```

Start sshd without enabling at boot (sudo required).

### stop

```bash
sshm stop
```

Stop sshd, disable at boot, and drop all INCOMING SSH connections (sudo required).

## SHORTCUTS

```
c=create  r=read  u=update  d=delete  l=list  t=test
kc=key_create  kr=key_read  kd=key_delete  kl=key_list
i=init  p=perms  h=help  ha=help all
```

## EXAMPLES

### Complete Workflow

```bash
sshm init
sshm key_create prod
sshm create server1 192.168.1.100 22 root ~/.ssh/keys/prod
ssh-copy-id -i ~/.ssh/keys/prod.pub root@192.168.1.100
ssh server1
```

### Deploy Key to Server

```bash
sshm key_read prod
# or: ssh-copy-id -i ~/.ssh/keys/prod.pub user@server
```

## FILES

- `~/.ssh/config` - Main config (includes hosts/*)
- `~/.ssh/hosts/*` - Individual host configs
- `~/.ssh/hosts/.ephemeral` - List of ephemeral hostnames (not deleted on test failure)
- `~/.ssh/keys/*` - Keypairs (private 600, public 600)
- `~/.ssh/mux/*` - Multiplexing sockets

## SEE ALSO

- `CLAUDE.md` - Architecture and usage reference
- `rcm.md` - RC deployment

## AUTHOR

Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License)
