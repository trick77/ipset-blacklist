ipset-blacklist
===============

A Bash shell script which uses ipset and iptables to ban a large number of IP addresses published in IP blacklists.
 Ipset uses a hashtable to store/fetch IP addresses and thus the IP lookup is a lot (!) faster than thousands of
  sequentially parsed iptables ban rules.

The ipset command doesn't work under OpenVZ. It works fine on dedicated and fully virtualized servers like KVM though.

## What's new
- 02/14/2020: Add 'install.sh' script, that installs the systemd 'badips.service'  @ Dmytro Gierman
- 02/12/2020: Fork from https://github.com/trick77/ipset-blacklist into https://github.com/AcckiyGerman/ipset-blacklist
-
- 10/17/2018: Added support for CIDR aggregation if iprange command is available
- 10/17/2018: Merged Shellcheck PR from [@extremeshok](https://github.com/extremeshok)
- 05/10/2018: Added regex filter improvements from [@sbujam](https://github.com/sbujam)
- 08/15/2017: Filtering default gateway and multicast ranges
- 01/20/2017: Ignoring "Service unavailable" HTTP status code, removed IGNORE_CURL_ERRORS 
- 11/04/2016: Documentation added to show how to prevent fail2ban from inserting its rules above the ipset-blacklist when restarting the fail2ban service

## Quick start for Ubuntu
```shell
git pull https://github.com/AcckiyGerman/ipset-blacklist
cd ipset-blacklist
bash install.sh
systemctl start badips.service
```
Play with the system, ensure that your clients can connect to the system.  
  
If something does not work, stop the service:
  
    systemctl stop badips.service

You can delete service by:
   
    systemctl disable badips.service

## How it works
`install.sh` script downloads a list of bad IP addresses and put this list into `ipset`:

    ipset restore < /etc/ipset-blacklist/ip-blacklist.restore

`systemctl start badips.service` creates `iptables` rule to DROP all packets from this blacklist:

    iptables -I INPUT 1 -m set --match-set blacklist src -j DROP


If the `badips.service` is enabled, systemd service will restore this rules automatically after reboot.

## Cron job
In order to auto-update the blacklist, copy the following code into /etc/cron.d/update-blacklist.
 Don't update the list too often or some blacklist providers will ban your IP address. Once a day should be OK though.
```
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
33 23 * * *      root /usr/local/sbin/update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
```

## Check for dropped packets
Using iptables, you can check how many packets got dropped using the blacklist:

```
drfalken@wopr:~# iptables -L INPUT -v --line-numbers
Chain INPUT (policy DROP 60 packets, 17733 bytes)
num   pkts bytes target            prot opt in  out source   destination
1       15  1349 DROP              all  --  any any anywhere anywhere     match-set blacklist src
2        0     0 fail2ban-vsftpd   tcp  --  any any anywhere anywhere     multiport dports ftp,ftp-data,ftps,ftps-data
3      912 69233 fail2ban-ssh-ddos tcp  --  any any anywhere anywhere     multiport dports ssh
4      912 69233 fail2ban-ssh      tcp  --  any any anywhere anywhere     multiport dports ssh
```
Since iptable rules are parsed sequentally, the ipset-blacklist is most effective if it's the **topmost** rule in
 iptable's INPUT chain. However, restarting fail2ban usually leads to a situation, where fail2ban inserts its rules
  above our blacklist drop rule. To prevent this from happening we have to tell fail2ban to insert its rules at the
   2nd position. Since the iptables-multiport action is the default ban-action we have to add a file to
    /etc/fail2ban/action.d:
```
tee << EOF /etc/fail2ban/action.d/iptables-multiport.local
[Definition]
actionstart = <iptables> -N f2b-<name>
              <iptables> -A f2b-<name> -j <returntype>
              <iptables> -I <chain> 2 -p <protocol> -m multiport --dports <port> -j f2b-<name>
EOF
```
(Please keep in in mind this is entirely optional, it just makes dropping blacklisted IP addresses most effective)

## Modify the blacklists you want to use
Edit the BLACKLIST array in /etc/ipset-blacklist/ipset-blacklist.conf to add or remove blacklists, or use it to add your own blacklists.
```
BLACKLISTS=(
"http://www.mysite.me/files/mycustomblacklist.txt" # Your personal blacklist
"http://www.projecthoneypot.org/list_of_ips.php?t=d&rss=1" # Project Honey Pot Directory of Dictionary Attacker IPs
# I don't want this: "http://www.openbl.org/lists/base.txt"  # OpenBL.org 30 day List
)
```
If you for some reason want to ban all IP addresses from a certain country, have a look at [IPverse.net's](http://ipverse.net/ipblocks/data/countries/) aggregated IP lists which you can simply add to the BLACKLISTS variable. For a ton of spam and malware related blacklists, check out this github repo: https://github.com/firehol/blocklist-ipsets

## Troubleshooting

```Set blacklist-tmp is full, maxelem 65536 reached```   
Increase the ipset list capacity. For instance, if you want to store up to 80,000 entries, add these lines to your ipset-blacklist.conf:  
```
MAXELEM=80000
```

```ipset v6.20.1: Error in line 2: Set cannot be created: set with the same name already exists```   
If this happens after changing the MAXELEM parameter: ipset seems to be unable to recreate an exising list with a different size. You will have to solve this manually by deleting and inserting the blacklist in ipset and iptables. A reboot will help as well and may be easier. You may want to remove /etc/ipset-blacklist/ip-blacklist.restore too because it may still contain the old MAXELEM size.

```ipset v6.12: No command specified: unknown argument -file```
You're using an outdated version of ipset which is not supported.
