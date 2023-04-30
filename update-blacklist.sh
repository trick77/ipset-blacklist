#!/usr/bin/env bash
#
# usage update-blacklist.sh <configuration file>
# eg: update-blacklist.sh /etc/ipset-blacklist/ipset-blacklist.conf
#

IPV4_REGEX="(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:/[0-9]{1,2})?"
IPV6_REGEX="(?:(?:[0-9a-f]{1,4}:){7,7}[0-9a-f]{1,4}|\
(?:[0-9a-f]{1,4}:){1,7}:|\
(?:[0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|\
(?:[0-9a-f]{1,4}:){1,5}(?::[0-9a-f]{1,4}){1,2}|\
(?:[0-9a-f]{1,4}:){1,4}(?::[0-9a-f]{1,4}){1,3}|\
(?:[0-9a-f]{1,4}:){1,3}(?::[0-9a-f]{1,4}){1,4}|\
(?:[0-9a-f]{1,4}:){1,2}(?::[0-9a-f]{1,4}){1,5}|\
[0-9a-f]{1,4}:(?:(?::[0-9a-f]{1,4}){1,6})|\
:(?:(?::[0-9a-f]{1,4}){1,7}|:)|\
::(?:[f]{4}(?::0{1,4})?:)?\
(?:(25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\.){3,3}\
(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])|\
(?:[0-9a-f]{1,4}:){1,4}:\
(?:(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\.){3,3}\
(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9]))\
(?:/[0-9]{1,3})?"

function exists() { command -v "$1" >/dev/null 2>&1 ; }
function count_entries() { wc -l "$1" | cut -d' ' -f1 ; }

if [[ -z "$1" ]]; then
  echo "Error: please specify a configuration file, e.g. $0 /etc/ipset-blacklist/ipset-blacklist.conf"
  exit 1
fi

# shellcheck source=ipset-blacklist.conf
if ! source "$1"; then
  echo "Error: can't load configuration file $1"
  exit 1
fi

IPSET_BLACKLIST_NAME_V4="${IPSET_BLACKLIST_NAME}_v4"
IPSET_BLACKLIST_NAME_V6="${IPSET_BLACKLIST_NAME}_v6"
IPSET_TMP_BLACKLIST_NAME_V4="${IPSET_TMP_BLACKLIST_NAME}_v4"
IPSET_TMP_BLACKLIST_NAME_V6="${IPSET_TMP_BLACKLIST_NAME}_v6"

if ! exists curl && exists egrep && exists grep && exists ipset && exists iptables && exists ip6tables && exists sed && exists sort && exists wc ; then
  echo >&2 "Error: searching PATH fails to find executables among: curl egrep grep ipset iptables ip6tables sed sort wc"
  exit 1
fi

# download cidr-merger from https://github.com/zhanhb/cidr-merger/releases
DO_OPTIMIZE_CIDR=no
if exists cidr-merger && [[ ${OPTIMIZE_CIDR:-yes} != no ]]; then
  DO_OPTIMIZE_CIDR=yes
fi

if [[ ! -d $(dirname "$IP_BLACKLIST_FILE") || ! -d $(dirname "$IP_BLACKLIST_RESTORE") || ! -d $(dirname "$IP6_BLACKLIST_FILE") ]]; then
  echo >&2 "Error: missing directory(s): $(dirname "$IP_BLACKLIST_FILE" "$IP_BLACKLIST_RESTORE" "$IP6_BLACKLIST_FILE" "$IP6_BLACKLIST_RESTORE"|sort -u)"
  exit 1
fi

# ipv4 create the ipset if needed (or abort if does not exists and FORCE=no)
if ! ipset list -n|command grep -q "$IPSET_BLACKLIST_NAME_V4"; then
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ipset v4 does not exist yet, add it using:"
    echo >&2 "# ipset create $IPSET_BLACKLIST_NAME_V4 -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
    exit 1
  fi
  if ! ipset create "$IPSET_BLACKLIST_NAME_V4" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
    echo >&2 "Error: while creating the initial ipset v4"
    exit 1
  fi
fi

# ipv6 create the ipset if needed (or abort if does not exists and FORCE=no)
if ! ipset list -n|command grep -q "$IPSET_BLACKLIST_NAME_V6"; then
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ipset v6 does not exist yet, add it using:"
    echo >&2 "# ipset create $IPSET_BLACKLIST_NAME_V6 -exist hash:net family inet6 hashsize ${HASHSIZE_V6:-16384} maxelem ${MAXELEM_V6:-131072}"
    exit 1
  fi
  if ! ipset create "$IPSET_BLACKLIST_NAME_V6" -exist hash:net family inet6 hashsize "${HASHSIZE_V6:-16384}" maxelem "${MAXELEM_V6:-131072}"; then
    echo >&2 "Error: while creating the initial v6 ipset"
    exit 1
  fi
fi

# ipv4 create the iptables binding if needed (or abort if does not exists and FORCE=no)
if ! iptables -nvL INPUT|command grep -q "match-set $IPSET_BLACKLIST_NAME_V4"; then
  # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
    echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_BLACKLIST_NAME_V4 src -j DROP"
    exit 1
  fi
  if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_BLACKLIST_NAME_V4" src -j DROP; then
    echo >&2 "Error: while adding the --match-set ipset rule to iptables"
    exit 1
  fi
fi

# ipv6 create the ip6tables binding if needed (or abort if does not exists and FORCE=no)
if ! ip6tables -nvL INPUT|command grep -q "match-set $IPSET_BLACKLIST_NAME_V6"; then
  # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
  if [[ ${FORCE:-no} != yes ]]; then
    echo >&2 "Error: ip6tables does not have the needed ipset INPUT rule, add it using:"
    echo >&2 "# ip6tables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -m set --match-set $IPSET_BLACKLIST_NAME_V6 src -j DROP"
    exit 1
  fi
  if ! ip6tables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -m set --match-set "$IPSET_BLACKLIST_NAME_V6" src -j DROP; then
    echo >&2 "Error: while adding the --match-set ipset rule to ip6tables"
    exit 1
  fi
fi

IP_BLACKLIST_TMP_FILE=$(mktemp)
IP6_BLACKLIST_TMP_FILE=$(mktemp)
for url in "${BLACKLISTS[@]}"
do
  IP_TMP_FILE=$(mktemp)
  (( HTTP_RC=$(curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o "$IP_TMP_FILE" -s -w "%{http_code}" "$url") ))
  if (( HTTP_RC == 200 || HTTP_RC == 302 || HTTP_RC == 0 )); then # "0" because file:/// returns 000
    command grep -Po "^$IPV4_REGEX" "$IP_TMP_FILE" | sed -r 's/^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)$/\1.\2.\3.\4/' >> "$IP_BLACKLIST_TMP_FILE"
    command grep -Pio "^$IPV6_REGEX" "$IP_TMP_FILE" >> "$IP6_BLACKLIST_TMP_FILE"
    [[ ${VERBOSE:-yes} == yes ]] && echo -n "."
  elif (( HTTP_RC == 503 )); then
    echo -e "\\nUnavailable (${HTTP_RC}): $url"
  else
    echo >&2 -e "\\nWarning: curl returned HTTP response code $HTTP_RC for URL $url"
  fi
  rm -f "$IP_TMP_FILE"
done

[[ ${VERBOSE:-no} == yes ]] && echo -e "\\n"

# sort -nu does not work as expected
sed -r -e '/^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|22[4-9]\.|23[0-9]\.)/d' "$IP_BLACKLIST_TMP_FILE" | sort -n | sort -mu >| "$IP_BLACKLIST_FILE"
sed -r -e '/^([0:]+\/0|fe80:)/Id' "$IP6_BLACKLIST_TMP_FILE" | sort -d | sort -mu >| "$IP6_BLACKLIST_FILE"

if [[ ${DO_OPTIMIZE_CIDR} == yes ]]; then
  [[ ${VERBOSE:-no} == yes ]] && echo -e "Optimizing entries...\\nFound: $(count_entries "$IP_BLACKLIST_FILE") IPv4, $(count_entries "$IP6_BLACKLIST_FILE") IPv6"
  cidr-merger -o "$IP_BLACKLIST_TMP_FILE" -o "$IP6_BLACKLIST_TMP_FILE" "$IP_BLACKLIST_FILE" "$IP6_BLACKLIST_FILE"
  [[ ${VERBOSE:-no} == yes ]] && echo -e "Saved: $(count_entries "$IP_BLACKLIST_TMP_FILE") IPv4, $(count_entries "$IP6_BLACKLIST_TMP_FILE") IPv6\\n"
  
  cp "$IP_BLACKLIST_TMP_FILE" "$IP_BLACKLIST_FILE"
  cp "$IP6_BLACKLIST_TMP_FILE" "$IP6_BLACKLIST_FILE"
fi

rm -f "$IP_BLACKLIST_TMP_FILE" "$IP6_BLACKLIST_TMP_FILE"

cat >| "$IP_BLACKLIST_RESTORE" <<EOF
#
# Blacklisted entries: $(count_entries "$IP_BLACKLIST_FILE") IPv4, $(count_entries "$IP6_BLACKLIST_FILE") IPv6
#
# Based on:
$(printf "#   - %s\n" "${BLACKLISTS[@]}")
#
create $IPSET_TMP_BLACKLIST_NAME_V4 -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_BLACKLIST_NAME_V4 -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
create $IPSET_TMP_BLACKLIST_NAME_V6 -exist hash:net family inet6 hashsize ${HASHSIZE_V6:-16384} maxelem ${MAXELEM_V6:-131072}
create $IPSET_BLACKLIST_NAME_V6 -exist hash:net family inet6 hashsize ${HASHSIZE_V6:-16384} maxelem ${MAXELEM_V6:-131072}
EOF

if [[ -s "$IP_BLACKLIST_FILE" ]]; then
  # can be IPv4 including netmask notation
  sed -rn -e '/^#|^$/d' -e "s/^([0-9./]+).*/add $IPSET_TMP_BLACKLIST_NAME_V4 \\1/p" "$IP_BLACKLIST_FILE" >> "$IP_BLACKLIST_RESTORE"

fi
if [[ -s "$IP6_BLACKLIST_FILE" ]]; then
  sed -rn -e '/^#|^$/d' -e "s/^(([0-9a-f:.]+:+[0-9a-f]*)+(\/[0-9]{1,3})?).*/add $IPSET_TMP_BLACKLIST_NAME_V6 \\1/Ip" "$IP6_BLACKLIST_FILE" >> "$IP_BLACKLIST_RESTORE"
fi


cat >> "$IP_BLACKLIST_RESTORE" <<EOF
swap $IPSET_BLACKLIST_NAME_V4 $IPSET_TMP_BLACKLIST_NAME_V4
swap $IPSET_BLACKLIST_NAME_V6 $IPSET_TMP_BLACKLIST_NAME_V6
destroy $IPSET_TMP_BLACKLIST_NAME_V4
destroy $IPSET_TMP_BLACKLIST_NAME_V6
EOF

ipset -file "$IP_BLACKLIST_RESTORE" restore

[[ ${VERBOSE:-no} == yes ]] && echo "Done!"

exit 0
