ipset-blacklist
===============

A set of shell scripts which use ipset and iptables to ban a large number of IP addresses published in IP blacklists. `ipset` uses a hashtable to store/fetch IP addresses and thus the IP lookup is a lot (!) faster than thousands of sequentially parsed iptables ban rules. However, the limit of an ipset list is 2^16 entries.

Note: Updating the blacklists takes a long time (8m 20s on a TPLink TL-WDR3600), and running at a low priority (with `nice` and `ionice`) is recommended to avoid impacting packet routing & firewall performance. 

## Quick start for OpenWRT
1. Copy the scripts to a temporary directory on your OpenWRT router
2. Run `sh install.sh`

# iptables filter rule
```
ipset create blacklist_net hash:net
ipset create blacklist_ip hash:ip
iptables -I INPUT -m set --match-set blacklist_net src -j DROP
iptables -I INPUT -m set --match-set blacklist_ip src -j DROP
```
Make sure to run this snippet in your firewall script. If you don't, the ipset blacklist and the iptables rule to ban the blacklisted ip addresses will be missing!

# Cron job
In order to auto-update the blacklist, copy the following code into /etc/cron.d/update-blacklist. Don't update the list too often or some blacklist providers will ban your IP address. Once a day should be OK though.
```
33 23 * * *      /bin/nice /usr/local/bin/update-blacklist.sh > /tmp/update-blacklist.log 2>&1
```

## Check for dropped packets
Using iptables, you can check how many packets got dropped using the blacklist:

```
drfalken@wopr:~# iptables -L -vn
Chain INPUT (policy DROP 3064 packets, 177K bytes)
 pkts bytes target     prot opt in     out     source               destination
   43  2498 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set blacklist src
```
