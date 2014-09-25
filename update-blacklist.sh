#!/bin/bash
IP_TMP=/tmp/ip.tmp
IP_BLACKLIST=/etc/ip-blacklist.conf
IP_BLACKLIST_TMP=/tmp/ip-blacklist.tmp
IP_BLACKLIST_CUSTOM=/etc/ip-blacklist-custom.conf # optional
BLACKLISTS=(
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
"http://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"  # TOR Exit Nodes
"http://www.maxmind.com/en/anonymous_proxies" # MaxMind GeoIP Anonymous Proxies
"http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List
"http://rules.emergingthreats.net/blockrules/rbn-ips.txt" # Emerging Threats - Russian Business Networks List
"http://www.spamhaus.org/drop/drop.lasso" # Spamhaus Don't Route Or Peer List (DROP)
"http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List
"http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
"http://www.autoshun.org/files/shunlist.csv" # Autoshun Shun List
"http://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
)

for i in "${BLACKLISTS[@]}"
do
    wget -O - "$i" | grep -o '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' >> $IP_BLACKLIST_TMP
done

sort -un $IP_BLACKLIST_TMP > $IP_BLACKLIST
rm $IP_BLACKLIST_TMP
wc -l $IP_BLACKLIST

ipset create blacklist_tmp hash:net

egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
ipset add blacklist_tmp $ip
done

ipset swap blacklist blacklist_tmp
ipset destroy blacklist_tmp
