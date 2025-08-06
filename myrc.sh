COLOR=34
export PATH=~/.ns/bin:$PATH

#export GTK_USE_PORTAL=1
#export MOZ_ENABLE_WAYLAND=1

function ramsum { ram | grep $1 | grep -v grep | awk '{print $0} {sum+=$1} END{printf "=========\n%.3f GB\n", sum/1048576}'; }
function y { yt-dlp -S vcodec:h264,res,acodec:aac "$1"; }
function ramsum { ram | grep $1 | grep -v grep | awk '{print $0} {sum+=$1} END{printf "=========\n%.3f GB\n", sum/1048576}'; } 

#export CF_Zone_ID=77bfd005fa888690e95abfd69a026c92
#export CF_Account_ID=7637f4a045359fdec0d4df5467a90ced
export CF_API_TOKEN=RQ0zb16a768FRDUs_ncJ3F6pakDq7PUXu5XTYsK1
export PBS_REPOSITORY=markc@pbs@pbs2.goldcoast.org:Backup
export PBS_PASSWORD=changeme_N0W
export PBS_FINGERPRINT=01:ea:b5:b8:3d:2e:06:49:de:38:a5:86:52:a7:e7:33:65:ac:64:48:a7:4c:a2:f9:54:8e:7e:c8:97:42:b4:3f
export PBS_LOG=warn
export MAILTO=markc@renta.net

alias b='proxmox-backup-client backup root.pxar:/home/markc --exclude .cache --exclude Nextcloud --exclude Downloads'
alias dlna='sc restart minidlna'
alias g='git status && git add . && git commit -a && git push'
alias phpdev='php -S localhost:8000 -t public -d error_log=php_error.log -d error_reporting=E_ALL -d display_errors=1 -d log_errors=1 &'
alias mysql=mariadb
alias incus-mem='echo "INCUS MEMORY USAGE"; ps aux | grep -E "incus|qemu" | grep -v grep | awk "{printf \"%-8s %-15s %8.1f MB %s\n\", \$2, \$1, \$6/1024, \$11}"; echo "Total: $(ps aux | grep -E "incus|qemu" | grep -v grep | awk "{sum+=\$6} END {printf \"%.1f MB (%.2f GB)\n\", sum/1024, sum/1024/1024}")"'
alias fio='fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=4G --readwrite=randrw --rwmixread=75'
alias lnew='laravel new --git --react --npm --pest --database=sqlite --dev --no-interaction'
alias sd='sqlite3 database/database.sqlite'
alias crd='composer run dev'
alias mfs='php artisan migrate:fresh --seed'
alias nah='git reset --hard && git clean -fd'
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'

alias gw='ssh gw'
alias b1='ssh b1'
alias b2='ssh b2'
alias b3='ssh b3'

alias a1='ssh a1'
alias a2='ssh a2'
alias a3='ssh a3'

alias mgo='ssh mgo'
alias motd='ssh motd'
alias nsorg='ssh nsorg'
alias haproxy='ssh haproxy'

alias my='ssh my'
alias sca='ssh sca'
alias mmc='ssh mmc'
alias ns3='ssh ns3'
alias mko='ssh mko'
alias mrn='ssh mrn'


alias mbi='ssh mbi'
alias mbs='ssh mbs'
alias msi="ssh msi"
alias mcn='ssh mcn'
alias mrc='ssh mrc'
#alias mcc='ssh mcc'
alias ccs='ssh ccs'

alias pve1='ssh pve1'
alias pve2='ssh pve2'
alias pve3='ssh pve3'
alias pve4='ssh pve4'
alias pve5='ssh pve5'

alias pbs1='ssh pbs1'
alias pbs2='ssh pbs2'
alias pbs3='ssh pbs3'
alias pbs4='ssh pbs4'
alias pbs5='ssh pbs5'

alias dns1='ssh dns1'
alias dns2='ssh dns2'

alias mecano='ssh mecano'
alias mectech='ssh mectech'
