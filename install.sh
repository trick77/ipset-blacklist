#!/bin/sh
# Install ipset blacklist scripts

REQUIRED_PACKAGES="ipset wget lua"

opkg install $REQUIRED_PACKAGES || (opkg update && opkg install $REQUIRED_PACKAGES) || exit

# copy the scripts to the PATH
mkdir -p /usr/local/bin
if ! grep /usr/local/bin /etc/profile; then echo "PATH=$PATH:/usr/local/bin" >> /etc/profile; fi
cp update_blacklist.sh load_blacklist.sh normalize_ip.lua uniq_cidr.lua /usr/local/bin
cp bindechex.lua /usr/share/lua

# load blacklists with firewall rules at boot
if ! grep load_blacklist.sh /etc/firewall.user
then
	echo "/bin/nice /usr/local/bin/load_blacklist.sh ip /etc/blacklist.ip.conf" >> /etc/firewall.user
	echo "/bin/nice /usr/local/bin/load_blacklist.sh net /etc/blacklist.net.conf" >> /etc/firewall.user
fi

# add cron job to update the blacklists (don't set this to update too often or you might get banned)
if ! grep update_blacklist.sh /etc/crontabs/root
then
	echo "17 10 * * * sleep 5 && nice update-blacklist.sh > /tmp/update_blacklist.log 2>&1" >> /etc/crontabs/root
fi
