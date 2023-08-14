    bash <(wget -qLO - https://raw.githubusercontent.com/markc/sh/master/bin/setup-sh)

# NetServa SH

This **SH**ell project is a set of shell aliases and env variables to help
manage your CLI shell from an upstream (Github) repository. The project
also includes an associated collection of shell scripts to setup and manage
a simple Web, Mail and DNS server which also provides a foundation for the
[NetServa HCP] PHP web interface.

Currently tested on:
```
- Ubuntu Lunar         # Most tested
- Manjaro Stable       # Partly done
- Alpine Edge          # Almost done
- Debian Bookworm      # Mostly done
- OpenWrt Latest       # WIP
```
## Usage

The simplest way to install and setup this project is to make sure `bash`,
`wget` and `git` are installed first then copy and paste this one-liner as
root. Please [review the script] at Github first...

    bash <(wget -qLO - https://raw.githubusercontent.com/markc/sh/master/bin/setup-sh)

To install this project manually, copy and paste these 3 lines below...

    git clone --depth 1 https://github.com/markc/sh ~/.sh
    ~/.sh/bin/shm install
    . ~/.shrc

The above will clone the Github repository to a folder called `.sh` in your
home directory and activate the system. If you have any problems with the
installed symlinks then just remove them with...

    shm remove

or to remove the entire system use...

    shm removeall

You can pull and push from your own forked repo without having to cd into
the ~/.sh installation first...

    shm pull
    shm push

Easily reset the RWX permsissions of all SH scripts to a safe(r) default...

    shm perms

Just type `alias` to see a set of simple aliases, typing `?` will show the
most common ones with some explanation of their usage and `eh` can be used
to customize this list. And yes, `nano` is the default editor of (my)
choice. Feel free to replace the `e` alias with **vi** or any other editor
by typing `es` (Edit Sh) and add `alias e='/usr/bin/vi'` and `export
EDITOR='/usr/bin/vi'` then ctl-x (for nano) which will make vi the default
editor. `es` edits the persistent ~/.myrc file and sources ~/.shrc (which
within itself sources ~/.myrc as personal env var and alias overrides.)

    ? ....... Show this help
    e ....... The nano Editor with a simplified interface
    f ....... Find named files and list them (recursive)
    i ....... Install a package
    l ....... Tail the end of the most common system Logfile
    n ....... Create a new Note in the users home dir
    m ....... Menu System (TODO)
    p ....... Search for a particular running Process
    q ....... Query text string within files (recursive)
    r ....... Remove a package
    s ....... Search for a package
    u ....... Update the package system
    .. ...... Change to parent directory
    eh ...... Edit this Help file
    em ...... Edit Menu file
    es ...... Edit ~/.myrc and re-execute ~/.shrc
    la ...... List All files including dotfiles
    ll ...... Long Listing
    ls ...... Short form List
    se ...... Sudo Edit text files as root
    sn ...... Show Notes created with "n"
    env ..... Show Environmental global variables
    alias ... To show all current Aliases

Some other useful aliases not list above are...

    ram ..... To show a simple sorted list of apps and their ram usage
    block ... Block or drop a an IP from accessing the system
    unblock . Unblock the above blocked IP
    shblock . Show all blocked IPs

Use `alias | grep log` to see some of the logging aliases, tweak or add
more using `es` to edit your custom and long term persistent `~/.myrc` file.

`n` (notes) and `sn` (show notes) is an ultra simple note taking system and
(TODO) should be expanded to keep the notes in a private Git repo (to allow
for the potential of passwords and any other sensitive info.)

## Bash Scripts

The above env var and alias management feature is useful in it's own right
and the only `~/.sh/bin` script needed is `~/.sh/bin/shm` (SH Manager) which
provides some basic functionality. `shm pull` and `shm push` are the most
frequently used and simply allow to `git pull` and `git push` from anywhere.

    shm [install|pull|push|remove|removeall|perms]

All the other scripts assist with server side virtual host management and
can be ignored if not needed. If used then the config files for each vhost
are stored in `~/.vhosts`. The initial (perhaps only) entry would be for
the current host (ie; when using LXD containers) using `hostname -f` as
the full filename path, ie; `cat ~/.vhosts/$(hostname -f)` should provide
the settings for the current host after `setup-fqdn` is run. It could be
set up manually using the below as an example of a non-public local LAN
domainname assuming that `hostname` returns `myhost`...
```
~ sethost sysadm@netserva.local
~ gethost # or cat ~/.vhosts/$(hostname -f)
ADMIN='sysadm'
AHOST='netserva.local'
AMAIL='admin@netserva.local'
ANAME='System Administrator'
APASS='phSdkd1XVxXWVDyT'
A_GID='1000'
A_UID='1000'
BPATH='/home/backups'
CIMAP='/etc/dovecot'
CSMTP='/etc/postfix'
C_DNS='/etc/powerdns'
C_FPM='/etc/php/8.2/fpm'
C_SQL='/etc/mysql'
C_SSL='/etc/ssl'
C_WEB='/etc/nginx'
DBMYS='/var/lib/mysql'
DBSQL='/var/lib/sqlite'
DHOST='localhost'
DNAME='sysadm'
DPASS='xb6D4CRDKSSkkoIl'
DPATH='/var/lib/sqlite/sysadm/sysadm.db'
DPORT='3306'
DTYPE='mysql'
DUSER='sysadm'
EPASS='j6Wrh0tWbbZfzh19'
EXMYS='mysql -BN sysadm'
EXSQL='sqlite3 /var/lib/sqlite/sysadm/sysadm.db'
IP4_0='192.168.0.2'
MHOST='netserva.local'
MPATH='/home/u/netserva.local/home'
OSMIR='archive.ubuntu.com'
OSREL='lunar'
OSTYP='ubuntu'
SQCMD='mysql -BN sysadm'
TAREA='Australia'
TCITY='Sydney'
UPASS='rSfQ66I137AHjedp'
UPATH='/home/u/netserva.local'
UUSER='sysadm'
U_GID='1000'
U_SHL='/bin/bash'
U_UID='1000'
VHOST='netserva.local'
VPATH='/home/u'
VUSER='admin'
V_PHP='8.2'
WPASS='phSdkd1XVxXWVDyT'
WPATH='/home/u/netserva.local/var/www'
WPUSR='wzoqqh'
WUGID='www-data'
```
If this host is a server then using `addvhost example.org` would add
yet another virtual host and create another config file called
`~/.vhosts/example.org` where `grep PASS ~/.vhosts/example.org` would
reveal the passwords used during the setup procedure.

## More documentation

For now, see [NetServa HCP] for more docmentation about using the hosting
management `setup-*` scripts. Some of the scripts in the `bin/` dir are
meant to be used from the PHP web interface but can generally also be used
standalone from the command line as well.

There are also some semi-related posts on my [personal blog].

_All scripts and documentation are Copyright (C) 1995-2023 Mark Constable and Licensed [AGPL-3.0]_

[Github]: https://github.com/markc/sh
[NetServa HCP]: https://github.com/markc/hcp
[review the script]: https://github.com/markc/sh/blob/master/bin/setup-sh
[AGPL-3.0]: http://www.gnu.org/licenses/agpl-3.0.html
[fork this project]: https://help.github.com/articles/fork-a-repo
[pull requests]: https://help.github.com/articles/using-pull-requests
[personal blog]: https://markc.blog
