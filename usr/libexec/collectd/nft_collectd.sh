#!/bin/sh

. /usr/share/libubox/jshn.sh

HOSTNAME="${COLLECTD_HOSTNAME:-localhost}"
INTERVAL="${COLLECTD_INTERVAL:-60}"

process_nftables() {
	local chain jsn syn_flood drop_from_wan

	chain="$1"
	jsn=$(cat /tmp/nft-statistics.json) || return
#nft list chain inet fw4 drop_from_wan
#nft list chain inet fw4 synflood_alt
#]
#echo $jsn | jq . | grep -E 'comment|packets|chain'
#exit

	drop_from_wan=$(echo $jsn | jq '. | select(.comment == "Drop wan IPv4 SYN packets, no syslog")')
	json_load "${drop_from_wan}"
    json_select expr
    json_select 4
    json_select counter
	json_get_vars packets bytes
	echo "PUTVAL \"$HOSTNAME/nft-$chain/syn_packets\" interval=$INTERVAL N:$packets"

	drop_from_wan=$(echo $jsn | jq '. | select(.comment == "Drop any remaining wan IPv4 packets, no syslog")')
	json_load "${drop_from_wan}"
    json_select expr
    json_select 3
    json_select counter
	json_get_vars packets bytes
	echo "PUTVAL \"$HOSTNAME/nft-$chain/wan_packets\" interval=$INTERVAL N:$packets"

	syn_flood=$(echo $jsn | jq '. | select(.comment=="Drop excess SYN packets, count")')
	json_load "${syn_flood}"
    json_select expr
    json_select 1
    json_select counter
	json_get_vars packets bytes
	echo "PUTVAL \"$HOSTNAME/nft-$chain/flood_packets\" interval=$INTERVAL N:$packets"

	json_cleanup
exit
}

# while not orphaned
while [ $(awk '$1 ~ "^PPid:" {print $2;exit}' /proc/$$/status) -ne 1 ] ; do
	process_nftables "syn_flood"
	sleep "${INTERVAL%%.*}"
done
