#!/bin/bash
IP_BLACKLIST_DIR=/etc/ipset-blacklist
IP_BLACKLIST_CONF=$IP_BLACKLIST_DIR/ipset-blacklist.conf

if [ ! -f $IP_BLACKLIST_DIR/ipset-blacklist.conf ]; then
   echo "Error: please download the ipset-blacklist.conf configuration file from GitHub and move it to $IP_BLACKLIST_CONF (see docs)"
   exit 1
fi

source $IP_BLACKLIST_DIR/ipset-blacklist.conf

for command in ipset iptables egrep grep curl sort uniq wc
do
    if ! which $command > /dev/null; then
        echo "Error: please install $command"
        exit 1
    fi
done

if [ ! -d $IP_BLACKLIST_DIR ]; then
    echo "Error: please create $IP_BLACKLIST_DIR directory"
    exit 1
fi

if [ -f /etc/ip-blacklist.conf ]; then
    echo "Error: please remove /etc/ip-blacklist.conf"
    exit 1
fi

if [ -f /etc/ip-blacklist-custom.conf ]; then
    echo "Error: please move /etc/ip-blacklist-custom.conf to the $IP_BLACKLIST_DIR directory and rename it to $IP_BLACKLIST_CUSTOM"
    exit 1
fi

IP_BLACKLIST_TMP=$(mktemp)
for i in "${BLACKLISTS[@]}"
do
    IP_TMP=$(mktemp)
    HTTP_RC=`curl --connect-timeout 10 --max-time 10 -o $IP_TMP -s -w "%{http_code}" -A "Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.2.3) Gecko/20100302 Firefox/3.6.3" "$i"`
    if [ $HTTP_RC -eq 200 -o $HTTP_RC -eq 302 ]; then
        grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' $IP_TMP >> $IP_BLACKLIST_TMP
	echo -n "."
    else
        echo -e "\nWarning: curl returned HTTP response code $HTTP_RC for URL $i"
    fi
    rm $IP_TMP
done
echo
sort $IP_BLACKLIST_TMP -n | uniq | sed -e '/^127.0.0.0\|127.0.0.1\|0.0.0.0/d'  > $IP_BLACKLIST
rm $IP_BLACKLIST_TMP
echo "Number of blacklisted IP/networks found: `wc -l $IP_BLACKLIST | cut -d' ' -f1`"
echo "create $IPSET_TMP_BLACKLIST_NAME -exist hash:net family inet hashsize $HASHSIZE maxelem $MAXELEM" > $IP_BLACKLIST_RESTORE
echo "create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize $HASHSIZE maxelem $MAXELEM" >> $IP_BLACKLIST_RESTORE

egrep -v "^#|^$" $IP_BLACKLIST | while IFS= read -r ip
do
    echo "add $IPSET_TMP_BLACKLIST_NAME $ip" >> $IP_BLACKLIST_RESTORE
done

if [ -f $IP_BLACKLIST_CUSTOM ]; then
    egrep -v "^#|^$" $IP_BLACKLIST_CUSTOM | while IFS= read -r ip
    do
        echo "add $IPSET_TMP_BLACKLIST_NAME $ip" >> $IP_BLACKLIST_RESTORE
    done
    echo "Number of IP/networks in custom blacklist: `wc -l $IP_BLACKLIST_CUSTOM | cut -d' ' -f1`"
fi

echo "swap $IPSET_BLACKLIST_NAME $IPSET_TMP_BLACKLIST_NAME" >> $IP_BLACKLIST_RESTORE
echo "destroy $IPSET_TMP_BLACKLIST_NAME" >> $IP_BLACKLIST_RESTORE
ipset restore < $IP_BLACKLIST_RESTORE
