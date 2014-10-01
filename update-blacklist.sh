#!/bin/sh

# config
IP_BLACKLIST=/etc/ip-blacklist.conf
WGET_LOG=/tmp/update_blacklist.log
BLACKLISTS="http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1
http://check.torproject.org/exit-addresses
http://www.maxmind.com/en/anonymous_proxies
http://www.spamhaus.org/drop/drop.lasso
http://danger.rulez.sk/projects/bruteforceblocker/blist.php
http://www.openbl.org/lists/base.txt
http://cinsscore.com/list/ci-badguys.txt
http://www.autoshun.org/files/shunlist.csv
http://lists.blocklist.de/lists/all.txt
http://rules.emergingthreats.net/blockrules/emerging-compromised.rules"

# download multiple URLs and output to stdout (log errors to logfile)
download_lists(){
    
    # clear the wget log
    echo -n > $WGET_LOG

    # download blacklists
    for i in $*
    do
        wget -O - "$i" 2>> $WGET_LOG | sed -r 's/,/\n/g' | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}"
    done
}

# create the temporary ipset, exit on error
ipset create blacklist_tmp hash:net || exit 1

# download the blacklists
download_lists $BLACKLISTS |\

# remove duplicate IPs
sort -u |\

# save blacklist to disk so it can be restored at boot
tee $IP_BLACKLIST |\

# iterate through list, saving IPs in temporary ipset
egrep -v "^#|^$" | while IFS= read -r ip
do 
    ipset add blacklist_tmp $ip
done

# activate the new blacklist
ipset swap blacklist blacklist_tmp

# destroy the temporary blacklist (now contains the old blacklist)
ipset destroy blacklist_tmp
