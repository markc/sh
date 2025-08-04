<!-- Created: 20150101 - Updated: 20250804 -->
<!-- Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License) -->

# Shell Enhancement System

A comprehensive collection of bash aliases and functions to enhance your command-line experience, extracted from the NetServa management system. This lightweight shell enhancement system provides useful shortcuts, cross-platform package management aliases, and powerful utility functions.

## Features

- **Cross-platform support**: Works on Linux (Debian/Ubuntu, Arch/Manjaro/CachyOS, Alpine), macOS, and OpenWRT
- **Smart package management**: Unified aliases that adapt to your system's package manager
- **Useful aliases**: Shortcuts for common tasks, navigation, editing, and system monitoring
- **Utility functions**: Enhanced file finding, service management, and more
- **SSH management**: Comprehensive SSH config and key management tool (sshm)
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

- **shrc.sh**: Main shell resource file containing all aliases and functions
- **myrc.sh**: Your personal customization file (sourced after shrc.sh)
- **sshm**: SSH management utility script
- **sshm.md**: Detailed documentation for the SSH manager

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

#### System Information
- `ff` - Fast system info (via fastfetch)
- `ram` - Show memory usage by process
- `p <pattern>` - Find processes matching pattern

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

### SSH Manager (sshm)

The included `sshm` tool helps manage SSH configurations and keys:

```bash
# Initialize SSH config structure
sshm init

# Create a new SSH host entry
sshm create myserver example.com 22 john

# List all configured hosts
sshm list

# Create a new SSH key
sshm key_create mykey
```

See [sshm.md](sshm.md) for complete documentation.

## Supported Platforms

The system automatically detects your OS and configures appropriate aliases:

- **Debian/Ubuntu**: apt-based package management
- **Arch/Manjaro/CachyOS**: pacman/yay package management
- **Alpine Linux**: apk package management
- **OpenWRT**: opkg package management
- **macOS**: Basic support (no package manager aliases)

## Tips

1. Use `es` to quickly edit your personal configuration
2. The `f` function is great for finding files: `f "*.txt"`
3. Package aliases work consistently across platforms: `i nginx` installs nginx on any supported OS
4. Check `ram` to see memory usage sorted by consumption
5. Use `sc` for service management: `sc restart nginx`

## Contributing

Feel free to submit issues and pull requests. When contributing:

1. Keep changes minimal and focused
2. Test on multiple platforms if possible
3. Document new features in this README
4. Follow the existing code style

## License

MIT License - See individual file headers for copyright information.# sh
