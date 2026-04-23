# Service log aliases for mail, web, and DNS servers
# Source from ~/.myrc on servers: source ~/.sh/_shrc.d/logs.sh

alias mgrep='mlog | grep '
alias alog='tail -f /var/log/nginx/access.log'
alias elog='tail -f /var/log/nginx/error.log'
alias mlog='tail -f /var/log/mail.log'
alias plog='tail -f ../log/php-errors.log'
alias dlog='journalctl -u pdns -f'

alias maillog="journalctl -f -n 10000 | stdbuf -oL grep 'warning: header Subject:' | sed -e 's/mail .*warning: header Subject:\(.*\)/\1/' -e 's/ from .*];//' -e 's/proto=.*$//'"
