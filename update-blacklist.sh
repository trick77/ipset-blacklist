#!/bin/bash
IP_BLACKLIST=/etc/ip-blacklist.conf
IP_BLACKLIST_TMP=/tmp/ip-blacklist.tmp
WGET_LOG=/tmp/update_blacklist.log
BLACKLISTS=(
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
"http://check.torproject.org/exit-addresses"  # TOR Exit Nodes
"http://www.maxmind.com/en/anonymous_proxies" # MaxMind GeoIP Anonymous Proxies
"http://www.spamhaus.org/drop/drop.lasso" # Spamhaus Don't Route Or Peer List (DROP)
"http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List
"http://www.openbl.org/lists/base.txt" # OpenBL.org 30 day List
"http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List
"http://www.autoshun.org/files/shunlist.csv" # Autoshun Shun List
"http://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
"http://rules.emergingthreats.net/blockrules/emerging-compromised.rules" # Emerging Threats - Compromised Hosts
)

rm $WGET_LOG

for i in "${BLACKLISTS[@]}"
do
    wget -O - "$i" 2>> $WGET_LOG | sed -r 's/,/\n/g' | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" >> $IP_BLACKLIST_TMP
done

sort -u $IP_BLACKLIST_TMP > $IP_BLACKLIST
rm $IP_BLACKLIST_TMP
wc -l $IP_BLACKLIST

ipset create blacklist_tmp hash:net

egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
ipset add blacklist_tmp $ip
done

ipset swap blacklist blacklist_tmp
ipset destroy blacklist_tmp
