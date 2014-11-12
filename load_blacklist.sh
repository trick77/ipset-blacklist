#!/bin/sh
# load a blacklist into an ipset
# Usage: load_blacklist.sh [name] [file]

FW_RULE="INPUT -m set --match-set blacklist_$1 src -j DROP"

ipset -exist create blacklist_$1 hash:$1 maxelem `wc -l $2 | cut -f1 -d" "`
if ! iptables -C $FW_RULE; then iptables -I $FW_RULE; fi

cat $2 | while IFS= read -r ip
do
    ipset -exist add blacklist_$1 $ip
done

