#!/usr/bin/env bash

# install ipset, if it is not installed
if ! command -v "ipset" >/dev/null 2>&1; then
  sudo apt install ipset -y;
fi

# link update script to the system path
chmod +x update-blacklist.sh
sudo ln -s $(pwd)/update-blacklist.sh /usr/local/sbin/update-blacklist.sh

# link config file into /etc/ipset-blacklist
sudo mkdir -p /etc/ipset-blacklist
sudo ln -s $(pwd)/ipset-blacklist.conf /etc/ipset-blacklist/ipset-blacklist.conf

# register a system service
sudo systemctl enable $(pwd)/badips.service

# get a list of bad IPs. Script fills ipset with a list of bad ips and enables the banning firewall rule.
sudo /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf

# Tell user how to control the service
GREEN='\033[0;32m'
NOCOLOR='\033[0m'
echo -e "$GREEN                    'badips' service has been installed.

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
    ipset list blacklist
$NOCOLOR"