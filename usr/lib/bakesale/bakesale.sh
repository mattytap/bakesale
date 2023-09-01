#!/bin/bash

# Script: /usr/lib/bakesale/bakesale.sh
# This script requires the bash interpreter

readonly BAKESALE_LIB_PATH="/usr/lib/bakesale"
readonly PRE_INCLUDE_PATH="/tmp/etc/bakesale-pre.include"
readonly POST_INCLUDE_PATH="/tmp/etc/bakesale-post.include"
readonly RULESET_PATH="/tmp/etc/ruleset4.nft"
readonly MAIN_NFT_PATH="/etc/bakesale.d/main.nft"

. /lib/functions.sh
. "$BAKESALE_LIB_PATH/pre_include.sh"
. "$BAKESALE_LIB_PATH/post_include.sh"

# Initialize debug mode from config file
DEBUG=1

# Log messages with priority
log() {
	local priority="$1"
	local message="$2"
	logger -t bakesale -p "daemon.$priority" "$message"
	printf "%s %s\n" "$priority" "$message"
}

# Handle errors
handle_error() {
	local errorMessage="$1"
	log "error" "$errorMessage"
	(( DEBUG )) || { cleanup_files; nft delete table inet bakesale 2>/dev/null; }
	return 1
}

# Format a list string with delimiters and wrappers
format_to_list_string() {
	local inputData="$1"
	local delimiter="$2"
	local wrapper="$3"
	local item result=""
	for item in $inputData; do
		result+="${result:+$delimiter}$wrapper$item$wrapper"
	done
	echo "$result"
}

# Cleanup temporary files
cleanup_files() {
	rm -f "$PRE_INCLUDE_PATH" "$POST_INCLUDE_PATH" "$RULESET_PATH"
}

# Flush nftables entries
flush_nft_entries() {
	local type="$1"
	local filter="$2"
	local entry
	for entry in $(nft -j list "$type" | jsonfilter -e "$filter"); do
		nft flush "$type" inet bakesale "$entry"
	done
}

# Add logging rules for 443 traffic to duiagnose BBC Sounds issues etc
monitor443() {
	# Check for existence of the logging rule in srcnat_wan
	if ! nft list chain inet fw4 srcnat_wan | grep -q 'SNAT to 443 in srcnat_wan:'; then
		nft insert rule inet fw4 srcnat_wan tcp dport 443 log prefix "\"SNAT to 443 in srcnat_wan: \""
	fi

	# Check for existence of the logging rule in srcnat_Net2Shield
	if ! nft list chain inet fw4 srcnat_Net2Shield | grep -q 'SNAT to 443 in srcnat_Net2Shield:'; then
		nft insert rule inet fw4 srcnat_Net2Shield tcp dport 443 log prefix "\"SNAT to 443 in srcnat_Net2Shield: \""
	fi

	# Check for existence of the logging rule in srcnat_Proton1VPN
	if ! nft list chain inet fw4 srcnat_Proton1VPN | grep -q 'SNAT to 443 in srcnat_Proton1VPN:'; then
		nft insert rule inet fw4 srcnat_Proton1VPN tcp dport 443 log prefix "\"SNAT to 443 in srcnat_Proton1VPN: \""
	fi
	if ! nft list chain inet fw4 reject_from_wan | grep -q 'ip saddr add @banIP:blocklistv4'; then
		nft insert rule inet fw4 reject_from_wan meta nfproto ipv4 iifname { "eth0", "eth5" } log prefix "\"ip saddr add @banIP:blocklistv4 \""
	fi
	log notice "nftables monitor443 rules inserted"
}

# Setup the service
setup() {
	local action="$1"

	cleanup_files
	config_load bakesale || return 1
	config_get_bool MONITOR443 global monitor443 1
	(( MONITOR443 )) && { monitor443 || return 1; }
	config_get_bool DEBUG global debug "$DEBUG"

	local dev zone zones

	for zone in lan wan; do
		config_get "$zone" global "${zone}_device"
		config_get zones global "${zone}_zone" "$zone"

		local currentZone
		for currentZone in $zones; do
			dev="$(fw4 -q zone "$currentZone" | sort -u)"
			[[ -n "$dev" ]] && eval "$zone=\"${!zone:+${!zone} }$dev\""
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
	(( DEBUG )) || cleanup_files
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
