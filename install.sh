#!/bin/bash

# See also:
# http://autoshun.org/
# http://doc.emergingthreats.net/bin/view/Main/EmergingFirewallRules
# http://adityamukho.com/blog/2014/06/18/using-ipset-manage-blacklists-firewall/
# http://daemonkeeper.net/781/mass-blocking-ip-addresses-with-ipset/
# http://www.stopforumspam.com/downloads/toxic_ip_cidr.txt

# Require git, ipset, and iptables
apt-get -qq --assume-yes install git ipset iptables > /dev/null

if [[ ! -e /usr/local/bin/update-blacklist.sh ]]; then

	git clone https://github.com/trick77/ipset-blacklist.git
	cd ipset-blacklist

	# Install in system
	mv update-blacklist.sh /usr/local/bin/
	chmod +x /usr/local/bin/update-blacklist.sh

	cd ../
	rm -R ipset-blacklist
fi

# Create a CRON script that runs each day to update our blacklists
if [[ ! -e /etc/cron.d/update-blacklist ]]; then
cat > /etc/cron.d/update-blacklist <<END
# Run at 3:33am each day
MAILTO=root
33 3 * * *      root /usr/local/bin/update-blacklist.sh
END

fi

# Check that this set exists (if not, create it)
ipset -L blacklist >/dev/null 2>&1
if [ $? -ne 0 ]; then
	ipset create blacklist hash:net
fi

echo "Please add the following line to IPTables to enable this blacklist"
echo "iptables -I INPUT -m set --match-set blacklist src -j DROP"

# Done
