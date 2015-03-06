ipset-blacklist
===============

A tiny Bash shell script which uses ipset and iptables to ban a large number of IP addresses published in IP blacklists. ipset uses a hashtable to store/fetch IP addresses and thus the IP lookup is a lot (!) faster than thousands of sequentially parsed iptables ban rules. However, the limit of an ipset list is 2^16 entries.

The ipset command doesn't work under OpenVZ. It works fine on dedicated and fully virtualized servers like KVM though.

## Quick start for Debian/Ubuntu based installations
As root run

bash <(curl -sSL https://raw.githubusercontent.com/trick77/ipset-blacklist/master/installUbuntu14_04.sh)

or

1. Copy update-blacklist.sh into /usr/local/bin
2. chmod +x /usr/local/bin/update-blacklist.sh
2. Modify update-blacklist.sh according to your needs. Per default, the blacklisted IP addresses will be saved to /etc/ip-blacklist.conf
3. apt-get install ipset
4. Create the ipset blacklist and insert it into your iptables input filter (see below). After proper testing, make sure to persist it in your firewall script or similar or the rules will be lost after the next reboot.
5. Auto-update the blacklist using a cron job

# iptables filter rule
```
ipset create blacklist hash:net
iptables -I INPUT -m set --match-set blacklist src -j DROP
```
Make sure to run this snippet in your firewall script. If you don't, the ipset blacklist and the iptables rule to ban the blacklisted ip addresses will be missing!

# Cron job
In order to auto-update the blacklist, copy the following code into /etc/cron.d/update-blacklist. Don't update the list too often or some blacklist providers will ban your IP address. Once a day should be OK though.
```
MAILTO=root
33 23 * * *      root /usr/local/bin/update-blacklist.sh
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
Edit the BLACKLIST array to add or remove blacklists, or use it to add your own blacklists.
```
BLACKLISTS=(
"http://www.mysite.me/files/mycustomblacklist.txt" # Your personal blacklist
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
# I don't want this: "http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
)
```
