ipset-blacklist
===============

A tiny Bash shell script which uses ipset and iptables to ban a large number of IP addresses published in IP blacklists. ipset uses a hashtable to store/fetch IP addresses and thus the IP lookup is a lot (!) faster than thousands of sequentially parsed iptables ban rules. However, the limit of an ipset list is 2^16 entries.

The ipset command doesn't work under OpenVZ. It works fine on dedicated and fully virtualized servers like KVM though.

## Install for Debian/Ubuntu based installations

	curl -sSL https://raw.githubusercontent.com/Xeoncross/ipset-blacklist/master/install.sh | bash

# Files

If you wish to add or remove IP addresses or CIDR ranges you can use the following additional files. You might have to create them.

- The blacklisted IP addresses will be saved to `/etc/ip-blacklist.conf` (this is auto-generated each cron run)
- You can add additional blacklisted IP/CIDR's to `/etc/ip-blacklist-custom.conf`
- If you wish to exclude IP's then add one each line to `/etc/ip-ignorelist.conf`

# iptables filter rule

    iptables -I INPUT -m set --match-set blacklist src -j DROP

Make sure to run this snippet in your firewall script. If you don't, the ipset blacklist and the iptables rule to ban the blacklisted ip addresses will be missing!

# Cron job

In order to auto-update the blacklist, the a cron jobs has been added to /etc/cron.d/update-blacklist

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
