ipset-blacklist
===============

A tiny Bash shell script which uses ipset and iptables to ban a large number of IP addresses published in IP blacklists. ipset uses a hashtable to store/fetch IP addresses and thus the IP lookup is a lot (!) faster than thousands of sequentially parsed iptables ban rules. ~~However, the limit of an ipset list is 2^16 entries.~~

The ipset command doesn't work under OpenVZ. It works fine on dedicated and fully virtualized servers like KVM though.

## What's new
- 11/11/2015: Merged all suggestions from https://github.com/drzraf
- 10/24/2015: Outsourced the entire configuration in it's own configuration file. Makes updating the shell script way easier!
- 10/22/2015: Changed the documentation, the script should be put in /usr/local/sbin not /usr/local/bin

## Quick start for Debian/Ubuntu based installations
1. wget -O /usr/local/sbin/update-blacklist.sh https://raw.githubusercontent.com/trick77/ipset-blacklist/master/update-blacklist.sh
2. chmod +x /usr/local/sbin/update-blacklist.sh
2. mkdir -p /etc/ipset-blacklist ; wget -O /etc/ipset-blacklist/ipset-blacklist.conf https://raw.githubusercontent.com/trick77/ipset-blacklist/master/ipset-blacklist.conf
2. Modify ipset-blacklist.conf according to your needs. Per default, the blacklisted IP addresses will be saved to /etc/ipset-blacklist/ip-blacklist.restore
3. apt-get install ipset
4. Create the ipset blacklist and insert it into your iptables input filter (see below). After proper testing, make sure to persist it in your firewall script or similar or the rules will be lost after the next reboot.
5. Auto-update the blacklist using a cron job

# iptables filter rule
```
# Enable blacklists
ipset restore < /etc/ipset-blacklist/ip-blacklist.restore
iptables -I INPUT -m set --match-set blacklist src -j DROP
```
Make sure to run this snippet in your firewall script. If you don't, the ipset blacklist and the iptables rule to ban the blacklisted ip addresses will be missing!

# Cron job
In order to auto-update the blacklist, copy the following code into /etc/cron.d/update-blacklist. Don't update the list too often or some blacklist providers will ban your IP address. Once a day should be OK though.
```
MAILTO=root
33 23 * * *      root /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
```

## Check for dropped packets
Using iptables, you can check how many packets got dropped using the blacklist:

```
drfalken@wopr:~# iptables -L -vn
Chain INPUT (policy DROP 3064 packets, 177K bytes)
 pkts bytes target     prot opt in     out     source               destination
   43  2498 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set blacklist src
```

## Modify the blacklists you want to use
Edit the BLACKLIST array in /etc/ipset-blacklist/ipset-blacklist.conf to add or remove blacklists, or use it to add your own blacklists.
```
BLACKLISTS=(
"http://www.mysite.me/files/mycustomblacklist.txt" # Your personal blacklist
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
# I don't want this: "http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
)
```
If you for some reason want to ban all IP addresses from a certain country, have a look at [IPverse.net's](http://ipverse.net/ipblocks/data/countries/) aggregated IP lists which you can simply add to the BLACKLISTS variable.

## Troubleshooting

Error: 
blacklist-tmp is full, maxelem 65536 reached   
Solution:
Increase the ipset list capacity. For instance, if you want to store up to 80,000 entries, add these lines to your ipset-blacklist.conf:  
```
MAXELEM=80000
HASHSIZE=$MAXELEM
```
