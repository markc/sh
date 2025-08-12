<!-- Created: 20150101 - Updated: 20250804 -->
<!-- Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License) -->

# Shell Enhancement System

A comprehensive collection of bash aliases and functions to enhance your command-line experience, extracted from the NetServa management system. This lightweight shell enhancement system provides useful shortcuts, cross-platform package management aliases, and powerful utility functions.

## Features

- **Cross-platform support**: Works on Linux (Debian/Ubuntu, Arch/Manjaro/CachyOS, Alpine), macOS, and OpenWRT
- **Smart package management**: Unified aliases that adapt to your system's package manager
- **Server management**: Essential aliases and functions for system administration and monitoring
- **Remote server deployment**: Built-in sync capability to deploy to remote servers
- **Service management**: Cross-platform service control functions (systemd, OpenRC, OpenWRT)
- **System monitoring**: Health checks, process monitoring, and security tools
- **SSH management**: Comprehensive shell management tool (shm)
- **NetServa compatibility**: Conditional support for NetServa infrastructure management
- **Customization**: Easy to extend with your own aliases and functions

## Installation

1. Clone this repository to your home directory:
```bash
git clone https://github.com/yourusername/sh.git ~/.sh
```

2. Add the following line to your shell startup file:
   
   **For ~/.bashrc** (most common):
   ```bash
   [[ -f ~/.sh/shrc.sh ]] && . ~/.sh/shrc.sh
   ```
   
   **For ~/.bash_profile or ~/.profile**:
   ```bash
   [[ -f ~/.sh/shrc.sh ]] && . ~/.sh/shrc.sh
   ```

3. (Optional) Install the SSH manager tool system-wide:
```bash
sudo cp ~/.sh/sshm /usr/local/bin/
sudo chmod +x /usr/local/bin/sshm
```

4. Reload your shell or source your startup file:
```bash
source ~/.bashrc  # or whichever file you modified
```

### Shell Startup Files Explained

- **~/.bashrc**: Executed for interactive non-login shells (e.g., opening a new terminal window)
- **~/.bash_profile**: Executed for login shells (e.g., SSH sessions, console login)
- **~/.profile**: Generic shell profile, used when bash_profile doesn't exist

Most desktop Linux users should add the source line to `~/.bashrc`. Server users who primarily connect via SSH might prefer `~/.bash_profile`.

## File Structure

- **_shrc**: Main shell resource file containing all aliases and functions (390+ lines)
- **_myrc**: Personal customization template (copy to ~/.myrc)  
- **_help**: Quick reference help file (sourced to ~/.help)
- **shm**: Shell management utility script (manages ~/.sh directory)
- **README.md**: This documentation file
- **LICENSE**: MIT License file

### Remote Server Compatibility

The shell enhancement system is designed to work on remote servers with minimal dependencies:

- **Conditional NetServa Support**: Only loads NetServa variables if ~/.ns exists
- **Cross-Platform Service Control**: Works with systemd, OpenRC, and OpenWRT
- **Minimal Dependencies**: Only requires bash and basic Unix tools
- **Automatic OS Detection**: Adapts package management aliases to the target OS

## Usage

### Key Aliases

#### Navigation & Files
- `..` - Go up one directory
- `la` - List all files with details (including hidden)
- `ll` - List files with details
- `f <pattern>` - Find files matching pattern (recursive)

#### Editing
- `e` - Edit with nano (or $EDITOR)
- `se` - Edit with sudo
- `es` - Edit your custom shell config (myrc.sh) and reload

#### System Information & Monitoring
- `ff` - Fast system info (via fastfetch)
- `ram` - Show memory usage by process
- `p <pattern>` - Find processes matching pattern
- `health` - Quick server health check
- `sysinfo` - System information summary
- `ports` - Show listening ports
- `procs` - Top CPU processes
- `disk` - Disk usage (human readable)
- `mem` - Memory usage (human readable)
- `logs` - Follow system logs
- `services` - Show running services
- `failed` - Show failed services
- `lastlog` - Recent login history

#### Package Management
The following aliases adapt to your system:
- `i <package>` - Install package
- `r <package>` - Remove package  
- `s <pattern>` - Search for packages
- `u` - Update system packages
- `lspkg <pattern>` - List installed packages

#### Service Management
- `sc <action> <service>` - Service control (start/stop/restart/status)

### Customization

Add your own aliases and functions to `~/.sh/myrc.sh`:

```bash
# Example custom aliases
alias myproject='cd ~/projects/myapp'
alias gs='git status'

# Example custom function
mybackup() {
    tar -czf backup-$(date +%Y%m%d).tar.gz "$@"
}
```

Your customizations in `myrc.sh` will override any defaults from `shrc.sh`.

### Shell Manager (shm)

The included `shm` tool manages the ~/.sh directory and shell enhancements:

```bash
# Install shell enhancements locally
shm install

# Sync to a remote server
shm sync user@server

# Test if properly installed
shm test

# Pull latest changes from git
shm pull

# Push changes to git
shm push "commit message"

# Show git status
shm status

# Show version information
shm version

# Fix file permissions
shm perms
```

#### Remote Server Deployment

Deploy shell enhancements to remote servers easily:

```bash
# Deploy to single server
shm sync root@server1

# Update local and deploy to multiple servers
shm pull
shm sync root@server1
shm sync root@server2
shm sync user@server3
```

The sync command automatically installs the shell enhancements on the remote server.

## Supported Platforms

The system automatically detects your OS and configures appropriate aliases:

- **Debian/Ubuntu**: apt-based package management
- **Arch/Manjaro/CachyOS**: pacman/yay package management
- **Alpine Linux**: apk package management
- **OpenWRT**: opkg package management
- **macOS**: Basic support (no package manager aliases)

## Tips

1. Use `es` to quickly edit your personal configuration and reload
2. The `f` function is great for finding files: `f "*.txt"`
3. Package aliases work consistently across platforms: `i nginx` installs nginx on any supported OS
4. Check `ram` to see memory usage sorted by consumption
5. Use `sc` for service management: `sc restart nginx`
6. Run `health` for a quick server status overview
7. Use `shm sync user@server` to deploy shell enhancements to remote servers
8. The `sx` function allows interactive remote command execution
9. Use `pstree_service nginx` to see process trees for services
10. All server monitoring aliases adapt to your OS (systemd, OpenRC, etc.)

## Contributing

Feel free to submit issues and pull requests. When contributing:

1. Keep changes minimal and focused
2. Test on multiple platforms if possible
3. Document new features in this README
4. Follow the existing code style

## License

MIT License - See individual file headers for copyright information.# sh
