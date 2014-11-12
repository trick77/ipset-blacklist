#!/bin/sh
# load a blacklist into an ipset
# arg1 - blacklist name
# arg2 - blacklist file

ipset -exist create hash:$1 blacklist_$1 maxelem `wc -l $2`
ipset -exist add blacklist blacklist_$1

cat $2 | while IFS= read -r ip
do
    ipset -exist add blacklist_$1 $ip
done

