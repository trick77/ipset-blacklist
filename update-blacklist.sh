#!/bin/sh

IP_BLACKLIST=/etc/ip-blacklist.conf
TEMP_FILE_NAME=/tmp/blacklist_temp
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
    http://rules.emergingthreats.net/blockrules/emerging-compromised.rules
    http://malc0de.com/bl/IP_Blacklist.ttx
    http://www.dshield.org/ipsascii.html?limit=10000
    "

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

# rename temp file variable name
NUM_IPS=$TEMP_FILE_NAME

# download the blacklists
download_lists $BLACKLISTS |\

# parse the blacklists
parse_list |\

# limit the number of IPs to 0xffffffff (ipset hardcoded maximum) (NOTE: this is also the number of possible IPv4 addresses)
#head -n 4294967295 |\

# save blacklist to disk so it can be restored at boot
tee $IP_BLACKLIST |\

# count number of IPs
wc -l > $NUM_IPS

# create the temporary ipset
ipset create blacklist_tmp hash:net maxelem `cat $NUM_IPS`

rm $NUM_IPS

# save each IP in the temporary ipset
< $IP_BLACKLIST while IFS= read -r ip
do 
    ipset add blacklist_tmp $ip
done

# activate the new ipset and destroy the old one
ipset swap blacklist blacklist_tmp
ipset destroy blacklist_tmp
