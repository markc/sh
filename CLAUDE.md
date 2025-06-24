# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NetServa SH is a shell environment and server management toolkit consisting of:
- Shell aliases and environment management (`~/.sh` installation)
- Server setup and virtual host management scripts
- Web, Mail, and DNS server configuration tools
- Foundation for NetServa HCP PHP web interface

Supported platforms: Debian Bookworm, Ubuntu Lunar, CachyOS (Arch), Alpine Edge, OpenWrt

## Commands

- Build: None (shell scripts repository)
- Lint: `shm perms` (check/fix permissions to 700/600)
- Test: No formal test suite (check script logic manually)
- Install: `bash <(wget -qLO - https://raw.githubusercontent.com/markc/sh/master/bin/setup-sh)`
- Management: `shm [install|pull|push|remove|removeall|perms]`

## Directory Structure

```
~/.sh/
├── bin/         # Shell scripts (700 permissions)
├── etc/         # Configuration file templates  
├── lib/         # Shell libraries (aliases, functions, netserva config)
├── web/         # Web interface components
├── _shrc        # Main shell rc file
├── _myrc        # Personal customizations (copied, not symlinked)
└── _help        # Help documentation
```

## Coding Style

- Shebang: `#!/usr/bin/env bash` (always first line)
- Header: Script name, creation/update dates, copyright notice
  ```bash
  #!/usr/bin/env bash
  # Created: 20170217 - Updated: 20250416
  # Copyright (C) 1995-2025 Mark Constable <markc@renta.net> (AGPL-3.0)
  ```
- Variables: 
  - UPPERCASE for global/exported vars (e.g., `VHOST`, `ADMIN`)
  - lowercase for local vars (e.g., `_UTMP`, `_POOL`)
  - Use `[[ -z $VAR ]]` for empty checks
- Functions: snake_case naming (e.g., `sh_install`, `gethost`)
- Indentation: 4 spaces (no tabs)
- Line length: 80 characters when reasonable
- Quotes: Double quotes for variable expansion, single quotes for literals
- Conditions: Always use `[[ ]]` instead of `[ ]`
- Command substitution: Use `$(command)` not backticks

## Script Patterns

### Usage/Help
```bash
[[ -z $1 || $1 =~ -h ]] && echo "Usage: scriptname [args]" && exit 1
```

### Environment Loading
```bash
[[ -z $REPO ]] && REPO=~/.sh
. /root/.vhosts/$VHOST  # Source host config
```

### SQL Queries via Heredoc
```bash
RESULT=$(cat <<EOS | $SQCMD
 SELECT column
   FROM table
  WHERE condition = '$VALUE'
EOS
)
```

### Error Handling
- Check for existing files/directories before creating
- Use informative echo statements prefixed with `###`
- Exit with appropriate codes (e.g., `exit 6` for database errors)

## Conventions

- All scripts copyright Mark Constable (AGPL-3.0)
- Root-level operations use `$SUDO` variable (set in environment)
- Host configs stored in `/root/.vhosts/` or `~/.vhosts/`
- Database access via `$SQCMD` (mysql/sqlite abstraction)
- Service management via `serva` wrapper script
- Use `chperms` to fix permissions after file operations
- Scripts should be idempotent (safe to run multiple times)
- Prefer editing existing files over creating new ones

## Key Environment Variables

Common variables sourced from host configs:
- `VHOST` - Virtual hostname/domain
- `UUSER` - System user
- `UPATH` - User home path
- `WPATH` - Web root path  
- `DTYPE` - Database type (mysql/sqlite)
- `SQCMD` - Database command
- `C_FPM` - PHP-FPM config path
- `C_WEB` - Web server config path
- `C_SSL` - SSL certificate path

## Testing Considerations

- Always test on clean systems
- Check for cross-platform compatibility (Ubuntu/Debian/Alpine/Arch)
- Verify idempotency by running scripts multiple times
- Test both mysql and sqlite database backends
- Ensure proper permissions are set (use `shm perms`)

