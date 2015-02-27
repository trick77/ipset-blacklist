#!/bin/bash
IP_BLACKLIST_RESTORE=/etc/ip-blacklist.conf
IP_BLACKLIST=/etc/ip-blacklist.list
IP_BLACKLIST_TMP=$(mktemp)
IP_BLACKLIST_CUSTOM=/etc/ip-blacklist-custom.conf # optional
BLACKLISTS=(
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
"http://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"  # TOR Exit Nodes
"http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List
"http://www.spamhaus.org/drop/drop.lasso" # Spamhaus Don't Route Or Peer List (DROP)
"http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List
"http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
"http://www.autoshun.org/files/shunlist.csv" # Autoshun Shun List
"http://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
"http://www.stopforumspam.com/downloads/toxic_ip_cidr.txt" # StopForumSpam
)
for i in "${BLACKLISTS[@]}"
do
    IP_TMP=$(mktemp)
    HTTP_RC=`curl -o $IP_TMP -s -w "%{http_code}" "$i"`
    if [ $HTTP_RC -eq 200 -o $HTTP_RC -eq 302 ]; then
        grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' $IP_TMP >> $IP_BLACKLIST_TMP
    else
        echo "Warning: curl returned HTTP response code $HTTP_RC for URL $i"
    fi
    rm $IP_TMP
done
sort $IP_BLACKLIST_TMP -n | uniq > $IP_BLACKLIST
rm $IP_BLACKLIST_TMP
wc -l $IP_BLACKLIST

ipset destroy blacklist_tmp
echo "create blacklist_tmp hash:net family inet hashsize 65536 maxelem 65536" > $IP_BLACKLIST_RESTORE
echo "create blacklist hash:net -exist family inet hashsize 65536 maxelem 65536" >> $IP_BLACKLIST_RESTORE

egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
    echo "add blacklist_tmp $ip" >> $IP_BLACKLIST_RESTORE
done

if [ -f $IP_BLACKLIST_CUSTOM ]; then
        egrep -v "^#|^$" $IP_BLACKLIST_CUSTOM | while IFS= read -r ip
        do
                echo "add blacklist_tmp $ip" >> $IP_BLACKLIST_RESTORE
        done
fi
echo "swap blacklist blacklist_tmp" >> $IP_BLACKLIST_RESTORE
echo "destroy blacklist_tmp" >> $IP_BLACKLIST_RESTORE
ipset restore < $IP_BLACKLIST_RESTORE
