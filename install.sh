#!/usr/bin/env bash

# install ipset, if ipset is executive is not exist.
if ! command -v "ipset" >/dev/null 2>&1; then
  sudo apt install ipset -y;
fi

# put a link to update program into path
chmod +x update-blacklist.sh
sudo ln -s $(pwd)/update-blacklist.sh /usr/local/sbin/update-blacklist.sh

# put a link to config into /etc
sudo mkdir -p /etc/ipset-blacklist
sudo ln -s $(pwd)/ipset-blacklist.conf /etc/ipset-blacklist/ipset-blacklist.conf

# register a system service
sudo systemctl enable $(pwd)/badips.service

# get a list of bad IPs. Script fills ipset with a list of bad ips and enables the banning firewall rule.
sudo /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf

# Tell user how to control the service
GREEN='\033[0;32m'
NOCOLOR='\033[0m'
echo -e "$GREEN                    Service is installed.

# To start the 'badips' service, type:
    systemctl start badips

# to stop 'badips' until the next reboot, run
    systemctl stop badips

# To delete service, run:
    systemctl disable badips

# To update list of IPs daily, put this to CRONTAB
    33 23 * * *      root /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf

# Check how many packets got dropped using the blacklist:
    iptables -L INPUT -v --line-numbers

# See the blacklisted IPs:
    ipset list blacklist $NOCOLOR
"