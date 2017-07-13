#!/bin/bash

# usage update-blacklist.sh <configuration file>
# eg: update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf

conf=${1:-/etc/ipset-blacklist/ipset-blacklist.conf}

if ! source "$conf"; then
    echo "Error: can't load configuration file $conf"
    exit 1
fi

if ! which curl egrep grep ipset iptables sed sort wc &> /dev/null; then
    echo >&2 "Error: searching PATH fails to find executables among: curl egrep grep ipset iptables sed sort wc"
    exit 1
fi

if [[ ! -d $(dirname "$IP_BLACKLIST") || ! -d $(dirname "$IP_BLACKLIST_RESTORE") ]]; then
    echo >&2 "Error: missing directory(s): $(dirname "$IP_BLACKLIST" "$IP_BLACKLIST_RESTORE"|sort -u)"
    exit 1
fi

if [ -f /etc/ip-blacklist.conf ]; then
    echo >&2 "Error: please remove /etc/ip-blacklist.conf"
    exit 1
fi

if [ -f /etc/ip-blacklist-custom.conf ]; then
    echo >&2 "Error: please reference your /etc/ip-blacklist-custom.conf as a file:// URI inside the BLACKLISTS array"
    exit 1
fi

# create the ipset if needed (or abort if does not exists and FORCE=no)
if ! ipset list -n|command grep -q "$IPSET_BLACKLIST_NAME"; then
    if [[ ${FORCE:-no} != yes ]]; then
	echo >&2 "Error: ipset does not exist yet, add it using:"
	echo >&2 "# ipset create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
	exit 1
    fi
    if ! ipset create "$IPSET_BLACKLIST_NAME" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
	echo >&2 "Error: while creating the initial ipset"
	exit 1
    fi
fi

# create the iptables binding if needed (or abort if does not exists and FORCE=no)
if ! iptables -nvL INPUT|command grep -q "match-set $IPSET_BLACKLIST_NAME"; then
    # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
    if [[ ${FORCE:-no} != yes ]]; then
	echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
	echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_BLACKLIST_NAME src -j DROP"
	exit 1
    fi
    if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_BLACKLIST_NAME" src -j DROP; then
	echo >&2 "Error: while adding the --match-set ipset rule to iptables"
	exit 1
    fi
fi

IP_BLACKLIST_TMP=$(mktemp)
for i in "${BLACKLISTS[@]}"
do
    IP_TMP=$(mktemp)
    let HTTP_RC=`curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o $IP_TMP -s -w "%{http_code}" "$i"`
    if (( $HTTP_RC == 200 || $HTTP_RC == 302 || $HTTP_RC == 0 )); then # "0" because file:/// returns 000
        command sed -n '
            /^.*[^0-9.]10\./d
            /^.*[^0-9.]127\./d
            /^.*[^0-9.]172\.1[6-9]\./d
            /^.*[^0-9.]172\.2[0-9]\./d
            /^.*[^0-9.]172\.3[0-1]\./d
            /^.*[^0-9.]192\.168\./d

            /^.*[^0-9.]00*\.00*\.00*\.00*[^0-9]/d
            /^.*[^0-9.]00*\.00*\.00*\.00*[	 ]*$/d

            /^[	 ]*10\./d
            /^[	 ]*127\./d
            /^[	 ]*172\.1[6-9]\./d
            /^[	 ]*172\.2[0-9]\./d
            /^[	 ]*172\.3[0-1]\./d
            /^[	 ]*192\.168\./d

            /^[	 ]*00*\.00*\.00*\.00*[^0-9]/d
            /^[	 ]*00*\.00*\.00*\.00*[	 ]*$/d

            s/^.*[^0-9.]\(\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}\(\/[0-9]\{1,2\}\)\{0,1\}\).*$/\1/p
            t

            s/^[	 ]*\(\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}\(\/[0-9]\{1,2\}\)\{0,1\}\).*$/\1/p
        ' "$IP_TMP" | awk 1 >> "$IP_BLACKLIST_TMP"
	[[ ${VERBOSE:-yes} == yes ]] && echo -n "."
    elif (( $HTTP_RC == 503 )); then
        echo -e "\nUnavailable (${HTTP_RC}): $i"
    else
        echo >&2 -e "\nWarning: curl returned HTTP response code $HTTP_RC for URL $i"
    fi
    rm -f "$IP_TMP"
done

# sort -nu does not work as expected
sort -n < "$IP_BLACKLIST_TMP" | sort -mu >| "$IP_BLACKLIST"
rm -f "$IP_BLACKLIST_TMP"

# family = inet for IPv4 only
cat >| "$IP_BLACKLIST_RESTORE" <<EOF
create $IPSET_TMP_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_BLACKLIST_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
EOF


# can be IPv4 including netmask notation
# IPv6 ? -e "s/^([0-9a-f:./]+).*/add $IPSET_TMP_BLACKLIST_NAME \1/p" \ IPv6
sed -n '
    s/^\([0-9./]\{1,\}\).*/add '"$IPSET_TMP_BLACKLIST_NAME"' \1/p
' "$IP_BLACKLIST" >> "$IP_BLACKLIST_RESTORE"

cat >> "$IP_BLACKLIST_RESTORE" <<EOF
swap $IPSET_BLACKLIST_NAME $IPSET_TMP_BLACKLIST_NAME
destroy $IPSET_TMP_BLACKLIST_NAME
EOF

# -file is not supported on older versions of ipset
ipset restore < "$IP_BLACKLIST_RESTORE"

if [[ ${VERBOSE:-no} == yes ]]; then
    echo
    echo "Number of blacklisted IP/networks found: `wc -l $IP_BLACKLIST | cut -d' ' -f1`"
fi
