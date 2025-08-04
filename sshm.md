<!-- Created: 20150101 - Updated: 20250804 -->
<!-- Copyright (C) 1995-2025 Mark Constable <mc@netserva.org> (MIT License) -->

# SSH Manager (sshm) Documentation

`sshm` is a comprehensive SSH configuration and key management tool that simplifies the management of SSH hosts and keys through an intuitive command-line interface.

## Overview

The SSH Manager helps you:
- Organize SSH host configurations in `~/.ssh/config.d/`
- Create and manage SSH keys with best practices
- Initialize proper SSH directory structure and permissions
- Maintain clean, modular SSH configurations

## Installation

```bash
# Copy to system path (requires sudo)
sudo cp sshm /usr/local/bin/
sudo chmod +x /usr/local/bin/sshm

# Or add to your personal bin directory
mkdir -p ~/bin
cp sshm ~/bin/
chmod +x ~/bin/sshm
# Ensure ~/bin is in your PATH
```

## Commands

### Host Management

#### Initialize SSH Structure
```bash
sshm init
```
Creates the necessary SSH directory structure:
- `~/.ssh/` directory with proper permissions (700)
- `~/.ssh/config` with secure cipher settings
- `~/.ssh/config.d/` for modular host configurations
- `~/.ssh/authorized_keys` with proper permissions (600)

#### Create Host
```bash
sshm create <Name> <Host> [Port] [User] [KeyFile]
```
Creates a new SSH host configuration.

**Parameters:**
- `Name`: Alias for the host (used with `ssh Name`)
- `Host`: Hostname or IP address
- `Port`: SSH port (default: 22)
- `User`: Username for connection (default: root)
- `KeyFile`: Path to identity file (default: none)

**Example:**
```bash
# Basic host
sshm create myserver example.com

# With custom settings
sshm create webserver example.com 2222 deploy ~/.ssh/web_key
```

#### Read Host
```bash
sshm read <Name>
```
Display the configuration values for a host.

#### Update Host
```bash
sshm update <Name>
```
Open the host configuration in your editor for manual editing.

#### Delete Host
```bash
sshm delete <Name>
```
Remove a host configuration.

#### List Hosts
```bash
sshm list
```
Display all configured hosts in a formatted table showing:
- Host alias
- Hostname/IP
- Port
- User
- Identity file

### Key Management

#### Create Key
```bash
sshm key_create <Name> [Comment] [Password]
```
Generate a new Ed25519 SSH key with modern security settings.

**Parameters:**
- `Name`: Key filename (stored in ~/.ssh/)
- `Comment`: Key comment (default: "hostname@lan")
- `Password`: Passphrase for key encryption (default: none)

**Example:**
```bash
# Basic key
sshm key_create mykey

# With comment and passphrase
sshm key_create deploy_key "deploy@production" "mysecretpass"
```

#### Read Key
```bash
sshm key_read <Name>
```
Display the public key contents (useful for copying to servers).

#### Delete Key
```bash
sshm key_delete <Name>
```
Remove both private and public key files.

#### List Keys
```bash
sshm key_list
```
Show all SSH keys with their fingerprints and metadata.

### Utility Commands

#### Fix Permissions
```bash
sshm perms
```
Reset proper permissions for all SSH files:
- Directories: 700
- Files: 600

#### Copy Key to Host
```bash
sshm copy <KeyName> <HostName>
```
Copy a public key to a remote host's authorized_keys file.

**Note:** This command requires that both the key and host exist in your configuration.

## Configuration Structure

After initialization, your SSH configuration will be organized as:

```
~/.ssh/
├── config              # Main config with Include directive
├── config.d/           # Individual host configurations
│   ├── myserver       # Each file contains one Host block
│   ├── webserver
│   └── ...
├── authorized_keys     # Public keys for incoming connections
├── mykey              # Private keys
├── mykey.pub          # Public keys
└── ...
```

### Main Config File

The `~/.ssh/config` file created by `sshm init` includes:
- Secure cipher specifications
- Include directive for config.d/* files
- Global SSH client settings:
  - TCP keepalive enabled
  - Server alive interval (30 seconds)
  - Agent forwarding enabled
  - Key agent integration

## Best Practices

1. **Use meaningful host aliases**: Choose names that clearly identify the server's purpose
2. **Organize by project**: Consider prefixing related hosts (e.g., `prod-web`, `prod-db`)
3. **Use key passphrases**: Add passphrases to keys containing sensitive access
4. **Regular key rotation**: Periodically generate new keys for security
5. **Backup your keys**: Keep secure backups of important private keys

## Examples

### Complete Setup for New Server

```bash
# Initialize SSH structure
sshm init

# Create a key for the server
sshm key_create prod_key "admin@production"

# Create host configuration
sshm create production prod.example.com 22 admin ~/.ssh/prod_key

# Copy key to server (if you have password access)
sshm copy prod_key production

# Connect
ssh production
```

### Managing Multiple Environments

```bash
# Development servers
sshm create dev-web dev.example.com 22 developer ~/.ssh/dev_key
sshm create dev-db dev-db.internal 22 developer ~/.ssh/dev_key

# Staging servers
sshm create stage-web stage.example.com 22 deploy ~/.ssh/stage_key
sshm create stage-db stage-db.internal 22 deploy ~/.ssh/stage_key

# Production servers
sshm create prod-web prod.example.com 22 deploy ~/.ssh/prod_key
sshm create prod-db prod-db.internal 22 deploy ~/.ssh/prod_key

# List all configurations
sshm list
```

## Troubleshooting

### Permission Denied Errors
Run `sshm perms` to fix file permissions.

### Host Key Verification Failed
This is a security feature. Verify the host's fingerprint before accepting.

### Key Already Exists
The tool prevents overwriting existing keys. Delete the old key first if needed:
```bash
sshm key_delete oldkey
sshm key_create oldkey
```

### Include Directive Not Working
Ensure your SSH client version supports the Include directive (OpenSSH 7.3+):
```bash
ssh -V
```

## Security Notes

- All keys are generated using Ed25519 algorithm (modern and secure)
- Keys use 100 KDF rounds for added security
- The tool enforces proper file permissions automatically
- Config includes only secure ciphers by default
- Consider using SSH agent for key management

## Exit Codes

The tool uses specific exit codes for different scenarios:
- 0: Success
- 1-250: Various errors
- 251: Success with message
- 252: Info message
- 253: Warning message
- 254: Warning with empty content
- 255: Error with empty content