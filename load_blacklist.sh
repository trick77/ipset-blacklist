#!/bin/sh
# load a blacklist into an ipset
# arg1 - blacklist name
# arg2 - blacklist file

cat $2 | while IFS= read -r ip
do
    ipset add blacklist_$1 $ip
done

