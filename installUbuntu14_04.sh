#!/bin/sh

#Install prereqs
for command in ipset iptables egrep grep curl sort uniq wc
do
    if ! which $command > /dev/null; then
        echo "Installing $command"
		apt-get install -y $command
    fi
done

#Make folder
mkdir /etc/ipset-blacklist

#Put update script in cron daily to keep it up to date
\curl -sSL https://raw.githubusercontent.com/trick77/ipset-blacklist/master/update-blacklist.sh > /etc/cron.daily/update-blacklist.sh
chmod +x /etc/cron.daily/update-blacklist.sh

#This runs every time the network is brought up (so you have blocks at reboot)
\curl -sSL https://raw.githubusercontent.com/trick77/ipset-blacklist/master/blacklistInit >  /etc/network/if-pre-up.d/blacklistInit
chmod +x /etc/network/if-pre-up.d/blacklistInit

#Create the needed ipset
ipset create blacklist hash:net

#Fill up the blacklist set
/etc/cron.daily/update-blacklist.sh

#Set the blacklist set to drop
iptables -I INPUT -m set --match-set blacklist src -j DROP

#save the current firewall config to be reapplied at restart
iptables-save | tee /etc/iptables.rules


