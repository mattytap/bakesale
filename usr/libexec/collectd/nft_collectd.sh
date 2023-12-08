#!/bin/sh

HOSTNAME="${COLLECTD_HOSTNAME:-localhost}"
INTERVAL="${COLLECTD_INTERVAL:-60}"

process_nftables() {
    local chain jsn syn_flood drop_from_wan

    chain="$1"
    drop_from_wan=$(cat /tmp/nft-drop_from_wan.json) || return
    syn_flood=$(cat /tmp/nft-syn_flood.json) || return

    syn_packets=$(echo "$drop_from_wan" | jq -r '.nftables[2].rule.expr[3].counter | .packets')
    wan_packets=$(echo "$drop_from_wan" | jq -r '.nftables[3].rule.expr[2].counter | .packets')
    flood_packets=$(echo "$syn_flood" | jq -r '.nftables[3].rule.expr[0].counter | .packets')

    echo "PUTVAL \"$HOSTNAME/nft-$chain/syn_packets\" interval=$INTERVAL N:$syn_packets"
    echo "PUTVAL \"$HOSTNAME/nft-$chain/wan_packets\" interval=$INTERVAL N:$wan_packets"
    echo "PUTVAL \"$HOSTNAME/nft-$chain/flood_packets\" interval=$INTERVAL N:$flood_packets"
}

# while not orphaned
while [ $(awk '$1 ~ "^PPid:" {print $2;exit}' /proc/$$/status) -ne 1 ]; do
    process_nftables "syn_flood"
    sleep "${INTERVAL%%.*}"
done
