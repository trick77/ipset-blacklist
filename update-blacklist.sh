#!/bin/sh

IP_BLACKLIST=/etc/ip-blacklist.conf
WGET_LOG=/tmp/update_blacklist.log
BLACKLISTS="
    http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1
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
        wget --no-check-certificate -O - "$i" 2>> $WGET_LOG
    done
}

# extract IP addresses and remove duplicates
parse_list(){
    # make sure each IP address is on a seperate line
    sed -r 's/,/\n/g' |\
    
    # extract the IP addresses
    grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" |\
    
    # remove duplicates
    sort -u
}

# create the temporary ipset, exit on error
ipset create blacklist_tmp hash:net || exit 1

# download the blacklists
download_lists $BLACKLISTS |\

# parse the blacklists
parse_list |\

# save blacklist to disk so it can be restored at boot
tee $IP_BLACKLIST |\

# save each IP in the temporary ipset
while IFS= read -r ip
do 
    ipset add blacklist_tmp $ip
done

# activate the new ipset and destroy the old one
ipset swap blacklist blacklist_tmp
ipset destroy blacklist_tmp
