#!/bin/bash

# Script: /usr/lib/bakesale/bakesale.sh

# Function for logging
log() {
    local priority="$1"
    local message="$2"
    logger -t bakesale -p "daemon.$priority" "$message"
    printf "$priority $message\n"
}

# Function to create a formatted list from input
# $1: the input data
# $2: the desired delimiter for the output list
# $3: the wrapper for each element in the output list
mklist() {
    # Store the function's arguments in clearly named variables
    local inputData="$1"
    local delimiter="$2"
    local wrapper="$3"

    # Use 'echo' to print the input data, 'tr' replaces newline characters with spaces
    echo "$inputData" | tr '\n' ' ' | \
    # Use 'sed' for formatting (Awk doesn't handle rogue whitespace consistently):
    #    1. Replace leading spaces with the wrapper
    #    2. Replace trailing spaces with the wrapper
    sed -e "s/^\s*/$wrapper/" -e "s/\s*$/$wrapper/" | \
    #    3. Replace remaining spaces (which separate list elements) with the wrapper, delimiter, and another wrapper
    sed -e "s/\([^.]\)\s\+\([^.]\)/\1$wrapper$delimiter$wrapper\2/g"
}

delete_includes() {
    rm -f "/tmp/etc/bakesale-pre.include"
    rm -f "/tmp/etc/bakesale-post.include"
}

cleanup() {
    delete_includes
    rm -f "/tmp/etc/ruleset4.nft"
    nft delete table inet bakesale 2>/dev/null
}

setup() {
	local action="$1"

	rm -f "/tmp/etc/bakesale-pre.include" #
	rm -f "/tmp/etc/bakesale-post.include" #

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
		if [ -z "${!zone}" ]; then
			return 1
		fi
	done

	[ "$action" = "start" ] && nft delete table inet bakesale 2>/dev/null

	mkdir -p "/tmp/etc" || return 1
	create_pre_include || return 1
	create_post_include || return 1

	if [ "$action" = "reload" ]; then
		for i in $(nft -j list chains | jsonfilter -e '@.nftables[@.chain.table="bakesale"].chain.name'); do
			nft flush chain inet bakesale "$i"
		done
		for i in $(nft -j list maps | jsonfilter -e '@.nftables[@.map.table="bakesale"].map.name'); do
			nft flush map inet bakesale "$i"
		done
	fi

	nft -f "/etc/bakesale.d/main.nft" || return 1
	nft list ruleset > /tmp/etc/ruleset4.nft
	[ "$DEBUG" != 1 ] && {
		rm -f "/tmp/etc/bakesale-pre.include"
		rm -f "/tmp/etc/bakesale-post.include"
		rm -f "/tmp/etc/ruleset4.nft"
	}
	return 0
}

