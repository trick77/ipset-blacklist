#!/bin/sh

set -e

GITHUB_ORIGIN=trick77/ipset-blacklist/master
REQUIRED_PACKAGES='iptables ipset wget curl'
CONFIG=/etc/ipset-blacklist/ipset-blacklist.conf

ALL_FILES='
    /etc/ipset-blacklist/ipset-blacklist.conf
    /etc/ipset-blacklist/ip-blacklist.list
    /etc/ipset-blacklist/ip-blacklist.restore
    /etc/ipset-blacklist/
    /usr/local/sbin/update-blacklist.sh
    /usr/local/sbin/ipset-blacklist-install.sh
    /etc/cron.d/update-blacklist.crontab
    /etc/cron.d/ipset-blacklist-install.crontab
'

IPSET_RESTORE_FILE=/etc/ipset-blacklist/ip-blacklist.restore
FAIL2BAN_CONFFILE=/etc/fail2ban/action.d/iptables-multiport.conf

main() {
    check_root
    check_debian
    detect_vyatta

    get_command_line "$@"

    eval "$action"
}

check_install() {
    packages_installed $REQUIRED_PACKAGES || install_packages $REQUIRED_PACKAGES

    fetch_if_not_installed /usr/local/sbin/update-blacklist.sh
    fetch_if_not_installed /usr/local/sbin/ipset-blacklist-install.sh
    fetch_if_not_installed /etc/cron.d/update-blacklist.crontab
    fetch_if_not_installed /etc/cron.d/ipset-blacklist-install.crontab

    update_config

    check_fail2ban_config

    # on vyatta variants (edgeos, vyos) install this script to run on boot
    if [ -n "$vyatta" ]; then
        check_vyatta_config
    else # otherwise call script from rc.local
        check_rc_local
    fi

    load_blacklist
}

usage() {
    cat <<'EOF'
Usage: [32m./ipset-blacklist-install.sh [1;35m[ACTION] [OPTIONS][0m
Install and configure or modify the installation of the ipset-blacklist related
scripts and conffiles.

Works only Debian based distributions for the time being.

This script requires root privileges.

Actions:
  [1m-h, --help, --usage,[0m
  [1mhelp, usage[0m                        Show this help screen and exit.
  [1minstall, check-install[0m             Install or repair scripts/conffiles,
                                     this is the default aciton.
  [1muninstall[0m                          Remove all scripts, keep conffile.
  [1mpurge[0m                              Remove all scripts/conffiles.
  [1mupdate[0m                             Update all scripts, write new config to
                                     [1;35m.new[0m.
  [1mload[0m                               Load current blacklist (or fetch new list
                                     and load.)
  [1munload[0m                             Unload blacklist.

Options:
  [1m--force[0m                            Always overwrite conffile.

Project hosted here: <[1;34mhttp://github.com/trick77/ipset-blacklist[0m>
EOF
}

get_command_line() {
    # default to not overwriting config, unless --force enabled, except for 'purge'
    keep_config=1
    # default action is install
    action=check_install

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help|--usage|help|usage)
                usage
                exit 0
                ;;
            load)
                action=load_blacklist
                shift
                ;;
            unload)
                action=unload_blacklist
                shift
                ;;
            install|check-install)
                action=check_install
                shift
                ;;
            uninstall)
                action=uninstall
                shift
                ;;
            purge)
                action=uninstall
                keep_config=0
                shift
                ;;
            update)
                action='uninstall; check_install'
                shift
                ;;
            --force)
                keep_config=0
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -ne 0 ]; then
        usage
        exit 1
    fi
}

uninstall() {
    unload_blacklist
    remove_fail2ban_config

    for installed_file in $ALL_FILES; do
        if [ -f "$installed_file" ]; then
            case "$installed_file" in
                *.conf)
                    [ "$keep_config" -ne 1 ] && rm -f "$installed_file"
                    ;;
                *)
                    rm -f "$installed_file"
                    ;;
            esac
        elif [ -d "$installed_file" ]; then
            rmdir "$installed_file" 2>/dev/null || :
        fi
    done

    # cleanup for vyatta variants (edgeos, vyos)
    if [ -n "$vyatta" ]; then
        remove_vyatta_config
    else
        remove_from_rc_local
    fi
}

load_blacklist() {
    if [ -s "$IPSET_RESTORE_FILE" ]; then
        while iptables -D INPUT   -m set --match-set blacklist src -j DROP 2>/dev/null; do :; done # delete any rules
        ipset restore < "$IPSET_RESTORE_FILE"
        iptables -I INPUT 1 -m set --match-set blacklist src -j DROP
    else
        # initial run, creates the iptables rule
        /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
    fi
}

unload_blacklist() {
    while iptables -D INPUT -m set --match-set blacklist src -j DROP 2>/dev/null; do :; done
    ipset destroy blacklist-tmp 2>/dev/null || :
    ipset destroy blacklist 2>/dev/null     || :
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error 'you must be root'
    fi
}

check_debian() {
    if [ ! -f /etc/debian_version ]; then
        error 'sorry, only Debian-based distributions are currently supported'
    fi
}

error() {
    echo >&2 '[1;31mERROR[0m: '"$@"
    exit 1
}

packages_installed() {
    for pkg in "$@"; do
        dpkg -l "$pkg" 2>/dev/null | grep -Eq '^ii' || return 1
    done
    return 0
}

install_packages() {
    apt-get -qqy update
    apt-get -qqy install "$@"
}

wget() {
    # this is required for the old wget in squeeze used by vyos stable (1.1.7)
    command wget --no-check-certificate "$@"
}

fetch() {
    wget -qO "$1" "https://raw.githubusercontent.com/${GITHUB_ORIGIN}/$2"
}

fetch_if_not_installed() {
    path=$1
    target_dir=${path%/*}
    target_file=${path##*/}

    mkdir -p "$target_dir"

    [ ! -f "$path" ] && fetch "$path" "$target_file"

    case "$path" in
        *.sh)
            chmod +x "$path"
            ;;
    esac
}

update_config() {
    config_dir=${CONFIG%/*}
    config_basename=${CONFIG##*/}
    vyatta_config_backup_dir="/config/user-data/ipset-blacklist"
    vyatta_config_backup="${vyatta_config_backup_dir}/$config_basename"

    mkdir -p "$config_dir"

    fetch "${CONFIG}.new" "$config_basename"

    if [ "$keep_config" -ne 1 ]; then
        # overwrite unconditionally
        mv "${CONFIG}.new" "$CONFIG"
    else
        if [ -f "$CONFIG" ]; then
            if diff "$CONFIG" "${CONFIG}.new" >/dev/null 2>&1; then
                rm "${CONFIG}.new"
            fi
        else
            if [ -n "$vyatta" -a -f "$vyatta_config_backup" ]; then
                cp "$vyatta_config_backup" "$CONFIG"
            else
                mv "${CONFIG}.new" "$CONFIG"
            fi
        fi
    fi

    if [ -n "$vyatta" ]; then
        # backup the config for restore after firmware upgrades

        mkdir -p "$vyatta_config_backup_dir"

        if [ ! -f "$vyatta_config_backup" ] || ! diff "$vyatta_config_backup" "$CONFIG" >/dev/null 2>&1; then
            cp "$CONFIG" "$vyatta_config_backup"
        fi
    fi
}

check_fail2ban_config() {
    if packages_installed fail2ban && [ -s "$FAIL2BAN_CONFFILE" ]; then
        # change iptables command to insert rules at location 2, if not already edited
        edited="/tmp/${FAIL2BAN_CONFFILE##*/}.work"
        sed '/^ *actionstart *=/,/^ *(#.*)*$/{
                s/\(ip[0-9]*tables[^ ]*  *\)\(-I  *[^0-9 ]\{1,\}\)\(  *[^0-9 ]\)/\1\2 2\3/
        }' "$FAIL2BAN_CONFFILE" > "$edited"

        if [ -s "$edited" ] && ! diff "$FAIL2BAN_CONFFILE" "$edited" >/dev/null 2>&1; then
            cp "$FAIL2BAN_CONFFILE" "$FAIL2BAN_CONFFILE".orig
            mv "$edited" "$FAIL2BAN_CONFFILE"
            service fail2ban restart
        fi
    fi
}

remove_fail2ban_config() {
    if packages_installed fail2ban && [ -s "$FAIL2BAN_CONFFILE" ]; then
        # remove modification to iptables command to insert rules at location 2
        edited="/tmp/${FAIL2BAN_CONFFILE##*/}.work"
        sed '/^ *actionstart *=/,/^ *(#.*)*$/{
                s/\(ip[0-9]*tables[^ ]*  *\)\(-I  *[^0-9 ]\{1,\}\) *2\(  *[^0-9 ]\)/\1\2\3/
        }' "$FAIL2BAN_CONFFILE" > "$edited"

        if [ -s "$edited" ] && ! diff "$FAIL2BAN_CONFFILE" "$edited" >/dev/null 2>&1; then
            cp "$FAIL2BAN_CONFFILE" "$FAIL2BAN_CONFFILE".ipset-blacklist
            mv "$edited" "$FAIL2BAN_CONFFILE"
            service fail2ban restart
        fi
    fi
}

detect_vyatta() {
    vyatta=
    if [ -f /config/config.boot ]; then
        vyatta=1
    fi
}

check_vyatta_config() {
    if [ -d /config/scripts ]; then
        mkdir -p /config/scripts/post-config.d

        load_script=/config/scripts/post-config.d/ipset-blacklist-install.sh

        fetch_if_not_installed "$load_script"

        # on vyos (not edgeos) the script must be invoked from the bootup script
        vyos_postconf=/config/scripts/vyatta-postconfig-bootup.script
        if [ -f "$vyos_postconf" ]; then
            if ! grep -Eq 'ipset-blacklist-install\.sh' "$vyos_postconf"; then
                echo "$load_script" >> "$vyos_postconf"
            fi
        fi
    fi
}

remove_vyatta_config() {
    if [ -d /config/scripts ]; then
        rm -f /config/scripts/post-config.d/ipset-blacklist-install.sh

        # on vyos (not edgeos) the script is invoked from the bootup script
        vyos_postconf=/config/scripts/vyatta-postconfig-bootup.script
        if [ -f "$vyos_postconf" ]; then
            sed '/ipset-blacklist-install\.sh/d' "$vyos_postconf" > "${vyos_postconf}.ipset-blacklist"

            if ! diff "$vyos_postconf" "${vyos_postconf}.ipset-blacklist" >/dev/null 2>&1; then
                mv "${vyos_postconf}.ipset-blacklist" "$vyos_postconf"
            else
                rm "${vyos_postconf}.ipset-blacklist"
            fi
        fi

        # remove config backup
        rm -rf /config/user-data/ipset-blacklist
    fi
}

check_rc_local() {
    if [ -f /etc/rc.local ]; then
        if ! grep -Eq 'ipset-blacklist-install\.sh' /etc/rc.local; then
            # default rc.local ends with 'exit 0' so we cannot just append
            # this is hardly perfect of course, but should mostly work
            (
                sed '/^exit */q' /etc/rc.local | sed '$d'
                echo '/usr/local/sbin/ipset-blacklist-install.sh check-install'
                sed -n '/^exit */,$p' /etc/rc.local
            ) > /tmp/rc.local.ipset-blacklist
            mv /tmp/rc.local.ipset-blacklist /etc/rc.local
            chmod +x /etc/rc.local
        fi
    fi
}

remove_from_rc_local() {
    if [ -f /etc/rc.local ]; then
        sed '/ipset-blacklist-install\.sh/d' /etc/rc.local > /etc/rc.local.ipset-blacklist

        if ! diff /etc/rc.local /etc/rc.local.ipset-blacklist >/dev/null 2>&1; then
            mv /etc/rc.local.ipset-blacklist /etc/rc.local
        else
            rm /etc/rc.local.ipset-blacklist
        fi
    fi
}

main "$@"
