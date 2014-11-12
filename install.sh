#!/bin/sh
# Install ipset blacklist scripts

opkg install ipset wget || (opkg update && opkg install ipset wget) || exit


mkdir -p /usr/local/bin
cp update_blacklist.sh load_blacklist.sh normalize_ip.lua uniq_cidr.lua /usr/local/bin
cp bindechex.lua /usr/share/lua


if ! grep load_blacklist.sh /etc/firewall.user
then
	echo "/bin/nice /bin/ionice /usr/local/bin/load_blacklist.sh ip /etc/blacklist.ip.conf" >> /etc/firewall.user
	echo "/bin/nice /bin/ionice /usr/local/bin/load_blacklist.sh net /etc/blacklist.net.conf" >> /etc/firewall.user
fi

if ! grep update_blacklist.sh /etc/crontabs/root
then
	echo "17 10 * * * sleep 5 && nice ionice update-blacklist.sh > /tmp/update_blacklist.log 2>&1" >> /etc/crontabs/root
fi
