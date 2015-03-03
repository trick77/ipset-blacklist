#!/bin/bash
IP_BLACKLIST_DIR=/etc/ip-blacklist
IPSET_BLACKLIST_NAME=blacklist # change it if it collides with a pre-existing ipset list
IPSET_TMP_BLACKLIST_NAME=${IPSET_BLACKLIST_NAME}-tmp
IP_BLACKLIST_RESTORE=${IP_BLACKLIST_DIR}/ip-blacklist.restore
IP_BLACKLIST=${IP_BLACKLIST_DIR}/ip-blacklist.list
IP_BLACKLIST_CUSTOM=${IP_BLACKLIST_DIR}/ip-blacklist-custom.list # optional, for your personal nemeses (no typo, plural)
HASHSIZE=65536 # the initial hash size for the set. Don't touch unless you know what you're doing.
MAXELEM=65536 # the maximal number of elements which can be stored in the set

# List of URLs for IP blacklists. Currently, only IPv4 is supported in this script, everything else will be filtered.
BLACKLISTS=(
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
"http://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"  # TOR Exit Nodes
"https://www.maxmind.com/en/anonymous-proxy-fraudulent-ip-address-list" # MaxMind GeoIP Anonymous Proxies
"http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List
"http://www.spamhaus.org/drop/drop.lasso" # Spamhaus Don't Route Or Peer List (DROP)
"http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List
"http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
"http://www.autoshun.org/files/shunlist.csv" # Autoshun Shun List
"http://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
"http://www.stopforumspam.com/downloads/toxic_ip_cidr.txt" # StopForumSpam
)

for command in ipset iptables egrep grep curl sort uniq wc
do
    if ! which $command > /dev/null; then
        echo "Error: please install $command"
        exit 1
    fi
done

if [ ! -d $IP_BLACKLIST_DIR ]; then
    echo "Error: please create $IP_BLACKLIST_DIR directory"
    exit 1
fi

if [ -f /etc/ip-blacklist.conf ]; then
    echo "Error: please remove /etc/ip-blacklist.conf"
    exit 1
fi

if [ -f /etc/ip-blacklist-custom.conf ]; then
    echo "Error: please move /etc/ip-blacklist-custom.conf to the $IP_BLACKLIST_DIR directory and rename it to $IP_BLACKLIST_CUSTOM"
    exit 1
fi

IP_BLACKLIST_TMP=$(mktemp)
for i in "${BLACKLISTS[@]}"
do
    IP_TMP=$(mktemp)
    HTTP_RC=`curl --connect-timeout 10 --max-time 10 -o $IP_TMP -s -w "%{http_code}" "$i"`
    if [ $HTTP_RC -eq 200 -o $HTTP_RC -eq 302 ]; then
        grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' $IP_TMP >> $IP_BLACKLIST_TMP
	echo -n "."
    else
        echo "\nWarning: curl returned HTTP response code $HTTP_RC for URL $i"
    fi
    rm $IP_TMP
done
echo
sort $IP_BLACKLIST_TMP -n | uniq | sed -e '/^127.0.0.0\|127.0.0.1\|0.0.0.0/d'  > $IP_BLACKLIST
rm $IP_BLACKLIST_TMP
echo "Number of blacklisted IP/networks found: `wc -l $IP_BLACKLIST | cut -d' ' -f1`"
echo "create $IPSET_TMP_BLACKLIST_NAME -exist hash:net family inet hashsize $HASHSIZE maxelem $MAXELEM" > $IP_BLACKLIST_RESTORE
echo "create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize $HASHSIZE maxelem $MAXELEM" >> $IP_BLACKLIST_RESTORE

egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
    echo "add $IPSET_TMP_BLACKLIST_NAME $ip" >> $IP_BLACKLIST_RESTORE
done

if [ -f $IP_BLACKLIST_CUSTOM ]; then
    egrep -v "^#|^$" $IP_BLACKLIST_CUSTOM | while IFS= read -r ip
    do
        echo "add $IPSET_TMP_BLACKLIST_NAME $ip" >> $IP_BLACKLIST_RESTORE
    done
    echo "Number of IP/networks in custom blacklist: `wc -l $IP_BLACKLIST_CUSTOM | cut -d' ' -f1`"
fi

echo "swap $IPSET_BLACKLIST_NAME $IPSET_TMP_BLACKLIST_NAME" >> $IP_BLACKLIST_RESTORE
echo "destroy $IPSET_TMP_BLACKLIST_NAME" >> $IP_BLACKLIST_RESTORE
ipset restore < $IP_BLACKLIST_RESTORE
