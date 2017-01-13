#!/bin/sh
\curl -sSL https://raw.githubusercontent.com/trick77/ipset-blacklist/master/update-blacklist.sh > /usr/local/sbin/update-blacklist.sh
mkdir -p /etc/ipset-blacklist ; wget -O /etc/ipset-blacklist/ipset-blacklist.conf https://raw.githubusercontent.com/trick77/ipset-blacklist/master/ipset-blacklist.conf
chmod +x /etc/cron.daily/update-blacklist.sh
yum install -y ipset
ipset create blacklist hash:net
/usr/local/sbin/cron.daily/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
iptables -I INPUT 1 -m set --match-set blacklist src -j DROP
iptables-save | tee /etc/sysconfig/iptables
