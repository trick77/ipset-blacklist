#!/bin/bash
IP_TMP=/tmp/ip.tmp
IP_BLACKLIST=/etc/ip-blacklist.conf
IP_IGNORELIST=/etc/ip-ignorelist.conf
IP_BLACKLIST_TMP=/tmp/ip-blacklist.tmp
IP_BLACKLIST_CUSTOM=/etc/ip-blacklist-custom.conf # optional
BLACKLISTS=(
# Well-known master lists
"http://www.spamhaus.org/drop/drop.txt" # Spamhaus Don't Route Or Peer List (DROP)
"http://www.spamhaus.org/drop/edrop.txt" # Spamhaus Extended Don't Route Or Peer List (EDROP)
"http://cinsscore.com/list/ci-badguys.txt" # C.I. Army Malicious IP List (http://cinsscore.com/#list)
"http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
"http://www.autoshun.org/files/shunlist.csv" # Autoshun Shun List
"http://lists.blocklist.de/lists/all.txt" # blocklist.de attackers
"http://www.stopforumspam.com/downloads/toxic_ip_cidr.txt" # Over 5,000,000 monthly contributors

# Additional IP/CIDR Lists
#"http://danger.rulez.sk/projects/bruteforceblocker/blist.php" # BruteForceBlocker IP List (small community ruleset)
#"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
#"http://www.dshield.org/ipsascii.html?limit=10000" # Recent DShield IP's
#"http://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=1.1.1.1"  # TOR Exit Nodes (also used in restricted countries!)
#"https://www.maxmind.com/en/anonymous_proxies" # MaxMind GeoIP Anonymous Proxies (also used in restricted countries!)
#"http://rules.emergingthreats.net/blockrules/emerging-compromised.rules"
#"http://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" # spamhaus drop + dshield list
)

# Search for $1 in the given array ($2)
# http://stackoverflow.com/a/8574392/99923
containsElement () {
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
}

# We can disable re-downloading and parsing the lists (if we only wanted to update the ignore list)
if [ -z "$1" ]; then
    for i in "${BLACKLISTS[@]}"
    do
        HTTP_RC=`curl -o $IP_TMP -s -w "%{http_code}" "$i"`
        if [ $HTTP_RC -eq 200 -o $HTTP_RC -eq 302 ]; then
            grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' $IP_TMP >> $IP_BLACKLIST_TMP
        else
            echo "Error: curl returned HTTP response code $HTTP_RC for URL $i"
        fi
    done
    sort $IP_BLACKLIST_TMP -n | uniq > $IP_BLACKLIST
    rm $IP_BLACKLIST_TMP
fi

wc -l $IP_BLACKLIST

# Default an empty ignore list
IGNOREIPS=()

# Read in "ignore" file (if exists) to allow overrides of our blacklists
if [ -f $IP_IGNORELIST ]; then
    IFS=$'\n' read -d '' -r -a IGNOREIPS < $IP_IGNORELIST
fi

ipset create blacklist_tmp hash:net
egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
    # Only add entries we not listed in our IGNORE file
    if ! containsElement "$ip" "${IGNOREIPS[@]}" ; then
        ipset add blacklist_tmp $ip
    fi
done

if [ -f $IP_BLACKLIST_CUSTOM ]; then
    egrep -v "^#|^$" $IP_BLACKLIST_CUSTOM | while IFS= read -r ip
    do
        ipset add blacklist_tmp $ip
    done
fi

ipset swap blacklist blacklist_tmp
ipset destroy blacklist_tmp
