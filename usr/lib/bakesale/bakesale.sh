#!/bin/bash

# Script: /usr/lib/bakesale/bakesale.sh

# Source helper scripts
. /usr/lib/bakesale/pre_include.sh
. /usr/lib/bakesale/post_include.sh

log() {
    local priority="$1"
    local message="$2"
    logger -t bakesale -p "daemon.$priority" "$message"
    printf "$priority $message\n"
}

formatListString() {
    local inputData="$1"
    local delimiter="$2"
    local wrapper="$3"
	# The function turns a list into a neat line, replacing any gaps with special markers and
	# making sure there are no extra spaces at the start or end.
    echo "$inputData" | tr '\n' ' ' | \
    sed -e "s/^\s*/$wrapper/" -e "s/\s*$/$wrapper/" | \
    sed -e "s/\([^.]\)\s\+\([^.]\)/\1$wrapper$delimiter$wrapper\2/g"
}

cleanup_files() {
    rm -f "/tmp/etc/bakesale-pre.include" "/tmp/etc/bakesale-post.include" "/tmp/etc/ruleset4.nft"
}

cleanup() {
    cleanup_files
    nft delete table inet bakesale 2>/dev/null
}

flush_nft_entries() {
    local type="$1"
    local filter="$2"
    for i in $(nft -j list "$type" | jsonfilter -e "$filter"); do
        nft flush "$type" inet bakesale "$i"
    done
}

setup() {
    local action="$1"

    cleanup_files
    config_load bakesale || return 1
    config_get_bool DEBUG global debug "$DEBUG"

    local dev zone zones

    for zone in lan wan; do
        config_get "$zone" global "${zone}_device"
        config_get zones global "${zone}_zone" "$zone"

        for i in $zones; do
            dev="$(fw4 -q zone "$i" | sort -u)"
            [ -n "$dev" ] && eval "${zone}=\"${!zone:+${!zone} }$dev\""
        done
        [ -z "${!zone}" ] && return 1
    done

    [ "$action" = "start" ] && nft delete table inet bakesale 2>/dev/null
    mkdir -p "/tmp/etc" || return 1
    create_pre_include || return 1
    create_post_include || return 1

    [ "$action" = "reload" ] && {
        flush_nft_entries "chains" '@.nftables[@.chain.table="bakesale"].chain.name'
        flush_nft_entries "maps" '@.nftables[@.map.table="bakesale"].map.name'
    }

    nft -f "/etc/bakesale.d/main.nft" || return 1
    nft list ruleset > /tmp/etc/ruleset4.nft
    [ "$DEBUG" -ne 1 ] && cleanup_files

    return 0
}
