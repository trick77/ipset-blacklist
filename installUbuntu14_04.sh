#!/bin/sh
\curl -sSL https://raw.githubusercontent.com/bryanroscoe/ipset-blacklist/master/update-blacklist.sh > /etc/cron.daily/update-blacklist.sh
chmod +x /etc/cron.daily/update-blacklist.sh
\curl -sSL https://raw.githubusercontent.com/bryanroscoe/ipset-blacklist/master/blacklistInit >  /etc/network/if-pre-up.d/blocklistInit
chmod +x /etc/network/if-pre-up.d/blocklistInit
apt-get install -y ipset
ipset create blacklist hash:net
/etc/cron.daily/update-blacklist.sh
iptables -I INPUT -m set --match-set blacklist src -j DROP
iptables-save | tee /etc/iptables.rules
