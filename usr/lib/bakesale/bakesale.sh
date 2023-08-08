#!/bin/bash

# Script: /usr/lib/bakesale/bakesale.sh
# NOTE: THIS SCRIPT REQUIRES THE BASH INTERPRETER

DEBUG=1

# Variables for paths
BAKESALE_LIB_PATH="/usr/lib/bakesale"
PRE_INCLUDE_PATH="/tmp/etc/bakesale-pre.include"
POST_INCLUDE_PATH="/tmp/etc/bakesale-post.include"
RULESET_PATH="/tmp/etc/ruleset4.nft"
MAIN_NFT_PATH="/etc/bakesale.d/main.nft"

# Source helper scripts
. /lib/functions.sh
. "$BAKESALE_LIB_PATH/pre_include.sh"
. "$BAKESALE_LIB_PATH/post_include.sh"

log() {
    local priority="$1"
    local message="$2"
    logger -t bakesale -p "daemon.$priority" "$message"
    printf "%s %s\n" "$priority" "$message"
}

handle_error() {
	local errorMessage="$1"
	log error "$errorMessage"
	[[ "$DEBUG" -ne 1 ]] && {
		cleanup_files
		nft delete table inet bakesale 2>/dev/null
	}
	return 1
}

formatListString() {
    local inputData="$1"
    local delimiter="$2"
    local wrapper="$3"

    # Convert the list into a neat line, replace gaps with special markers and remove extra spaces.
    echo "$inputData" | tr '\n' ' ' | \
    sed -e "s/^\s*/$wrapper/" -e "s/\s*$/$wrapper/" | \
    sed -e "s/\([^.]\)\s\+\([^.]\)/\1$wrapper$delimiter$wrapper\2/g"
}

cleanup_files() {
    rm -f "$PRE_INCLUDE_PATH" "$POST_INCLUDE_PATH" "$RULESET_PATH"
}

flush_nft_entries() {
    local type="$1"
    local filter="$2"
    local i
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

        local i
        for i in $zones; do
            dev="$(fw4 -q zone "$i" | sort -u)"
            [[ -n "$dev" ]] && eval "${zone}=\"${!zone:+${!zone} }$dev\""
        done

        [[ -z "${!zone}" ]] && return 1
    done

    [[ "$action" == "start" ]] && nft delete table inet bakesale 2>/dev/null
    mkdir -p "/tmp/etc" || return 1
    create_pre_include || return 1
    create_post_include || return 1

    [[ "$action" == "reload" ]] && {
        flush_nft_entries "chains" '@.nftables[@.chain.table="bakesale"].chain.name'
        flush_nft_entries "maps" '@.nftables[@.map.table="bakesale"].map.name'
    }

    nft -f "$MAIN_NFT_PATH" || return 1
    nft list ruleset > "$RULESET_PATH"
    [[ "$DEBUG" -ne 1 ]] && cleanup_files

    return 0
}

case "$1" in
    start)
        setup start && log notice "Service started" || handle_error "Service start failed"
        ;;
    reload)
        setup reload && log notice "Service reloaded" || handle_error "Service reload failed"
        ;;
    stop)
        cleanup_files
        nft delete table inet bakesale 2>/dev/null
        log notice "Service stopped successfully"
        ;;
    *)
        echo "Usage: $0 {start|reload|stop}"
        exit 1
        ;;
esac
