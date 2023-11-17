#!/bin/sh

. /usr/share/libubox/jshn.sh

HOSTNAME="${COLLECTD_HOSTNAME:-localhost}"
INTERVAL="${COLLECTD_INTERVAL:-60}"

process_nftables() {
	local chain jsn syn_flood drop_from_wan

	chain="$1"
	drop_from_wan=$(cat /tmp/nft-drop_from_wan.json) || return
	syn_flood=$(cat /tmp/nft-syn_flood.json) || return

	json_load "${drop_from_wan}" || return
    json_select nftables
    json_select 3
    json_select rule
    json_select expr
    json_select 4
    json_select counter
	json_get_vars packets bytes
	echo "PUTVAL \"$HOSTNAME/nft-$chain/syn_packets\" interval=$INTERVAL N:$packets"

	json_load "${drop_from_wan}" || return
    json_select nftables
    json_select 4
    json_select rule
    json_select expr
    json_select 3
    json_select counter
	json_get_vars packets bytes
	echo "PUTVAL \"$HOSTNAME/nft-$chain/wan_packets\" interval=$INTERVAL N:$packets"

	json_load "${syn_flood}" || return
    json_select nftables
    json_select 4
    json_select rule
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
