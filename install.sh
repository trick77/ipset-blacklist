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
sudo systemctl enable $(pwd)/baniplist.service

# get a list of IPs
sudo /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf

# Tell user how to control the service
echo "
# Control Ban IP list
    service baniplist start|stop
# Delete service:
    systemctl disable baniplist
# Put to CRONTAB to update list of IPs daily:
33 23 * * *      root /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
"