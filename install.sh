#!/bin/sh
\curl -sSL https://raw.githubusercontent.com/trick77/ipset-blacklist/master/update-blacklist.sh > /etc/cron.daily/update-blacklist.sh
chmod +x /etc/cron.daily/update-blacklist.sh
yum install -y ipset
ipset create blacklist hash:net
/etc/cron.daily/update-blacklist.sh