#!/bin/bash

# File: /usr/lib/bakesale/post_include.sh

# Called by: /usr/lib/bakesale/bakesale.sh

# Source helper scripts
. /usr/lib/bakesale/post_include_user_set.sh
. /usr/lib/bakesale/post_include_rules.sh

# Function to append values to the list
append_to_list() {
    list+=("$1" "$2")
}

# Reverse config_foreach and call the given function on each configuration item
config_foreach_reverse() {
	local list=()
	local item

	# Retrieve and append configuration items.
	config_foreach append_to_list "$1" "$2"

	# Reverse sort the list
	list=($(echo "${list[@]}" | tr ' ' '\n' | sort -r))

	for item in "${list[@]}"; do
		"$1" "$3"
	done
}

# Append to file function
append_to_file() {
	local content=$1
	echo "$content" >> "/tmp/etc/bakesale-post.include"
}

# Validation function for integer variables
validate_integer() {
	local value=$1
	local error_message=$2

	# Returns 1 if the value is invalid, else 0.
	{ ! ([ "$value" -ge 0 ] 2>/dev/null) || [ "$value" -lt 2 ] ;} && {
		log error "$error_message"
		return 1
	}
	return 0
}

# Rule for threaded clients
create_threaded_client_rule() {
	# Variables initialization and configuration fetching
	local class_bulk threaded_client_min_bytes threaded_client_min_connections

	# Validation for threaded_client_min_connections
	config_get threaded_client_min_connections global threaded_client_min_connections 10
	validate_integer "$threaded_client_min_connections" "Global option 'threaded_client_min_connections' contains an invalid value" || { log error "Invalid threaded_client_min_connections value."; return 1; }

	# Validation for threaded_client_min_bytes
	config_get threaded_client_min_bytes global threaded_client_min_bytes 10000
	validate_integer "$threaded_client_min_bytes" "Global option 'threaded_client_min_bytes' contains an invalid value" || { log error "Invalid threaded_client_min_bytes value."; return 1; }

	# Validation for DSCP class for bulk data
	config_get class_bulk global class_bulk le
	check_class "$class_bulk" || { log error "Global option 'class_bulk' contains an invalid DSCP class"; return 1; }

	# Append the required rules for threaded clients to the post include file
	append_to_file "add rule inet bakesale established_connection meter tc_detect { ip daddr . th dport . meta l4proto timeout 5s limit rate over $((threaded_client_min_connections - 1))/minute } add @threaded_clients { ip daddr . th dport . meta l4proto timeout 30s }"
	append_to_file "add rule inet bakesale threaded_client meter tc_orig_bulk { ip saddr . th sport . meta l4proto timeout 5m limit rate over $((threaded_client_min_bytes - 1)) bytes/hour } update @threaded_clients { ip saddr . th sport . meta l4proto timeout 5m } goto ct_set_$class_bulk"
	append_to_file "add rule inet bakesale threaded_client_reply meter tc_reply_bulk { ip daddr . th dport . meta l4proto timeout 5m limit rate over $((threaded_client_min_bytes - 1)) bytes/hour } update @threaded_clients { ip daddr . th dport . meta l4proto timeout 5m } goto ct_set_$class_bulk"
}

# Rule for threaded services
create_threaded_service_rule() {
	# Variables initialization and configuration fetching
	local class_high_throughput threaded_service_min_bytes threaded_service_min_connections

	# Validation for threaded_service_min_connections
	config_get threaded_service_min_connections global threaded_service_min_connections 3
	if ! echo "$threaded_service_min_connections" | grep -qE "^[0-9]+$" || [ "$threaded_service_min_connections" -lt 2 ]; then
		log error "Global option 'threaded_service_min_connections' contains an invalid value"
		return 1
	fi

	# Validation for threaded_service_min_bytes
	config_get threaded_service_min_bytes global threaded_service_min_bytes 1000000
	if ! echo "$threaded_service_min_bytes" | grep -qE "^[0-9]+$" || [ "$threaded_service_min_bytes" = 0 ]; then
		log error "Global option 'threaded_service_min_bytes' contains an invalid value"
		return 1
	fi

	# Validation for DSCP class for high throughput data
	config_get class_high_throughput global class_high_throughput af13
	class_high_throughput="$(echo "$class_high_throughput" | tr 'A-Z' 'a-z')"
	case "$class_high_throughput" in
	af11 | af12 | af13 | af21 | af22 | af23 | af31 | af32 | af33 | af41 | af42 | af43 | cs1 | cs2 | cs3 | cs4 | cs5 | cs6 | cs7 | be | ef) true ;;
	*) log error "Global option 'class_high_throughput' contains an invalid DSCP class"; return 1 ;;
	esac

	# Append the required rules for threaded services to the post include file
	echo "add rule inet bakesale established_connection meter ts_detect { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 5s limit rate over $((threaded_service_min_connections - 1))/minute } add @threaded_services { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 30s }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service ct original bytes < $threaded_service_min_bytes return" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service update @threaded_services { ip saddr . ip daddr and 255.255.255.0 . th dport . meta l4proto timeout 5m }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service goto ct_set_$class_high_throughput" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply ct reply bytes < $threaded_service_min_bytes return" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply update @threaded_services { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 5m }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply goto ct_set_$class_high_throughput" >> "/tmp/etc/bakesale-post.include"
}

# DSCP mark rule creation
create_dscp_mark_rule() {
	local wmm

	# Fetching configuration for WMM (Wi-Fi Multimedia)
	config_get_bool wmm global wmm 0

	# Append the required DSCP marking rules based on WMM settings
	if [ "$wmm" = 1 ]; then
		echo "add rule inet bakesale postrouting oifname \$lan ct mark and \$ct_dscp vmap @ct_wmm" >> "/tmp/etc/bakesale-post.include"
	fi
	echo "add rule inet bakesale postrouting ct mark and \$ct_dscp vmap @ct_dscp" >> "/tmp/etc/bakesale-post.include"
}

# Rule creation based on user configuration
create_user_rule() {
	local enabled family proto direction device dest dest_ip dest_port src src_ip src_port counter class name
	local nfproto l4proto oifname daddr dport iifname saddr sport verdict

	config_get_bool enabled "$1" enabled 1
	[ "$enabled" = 1 ] || return 0

	# Fetching various user-defined rule configurations
	config_get family "$1" family
	config_get proto "$1" proto
	config_get device "$1" device
	config_get direction "$1" direction
	config_get dest "$1" dest
	config_get dest_ip "$1" dest_ip
	config_get dest_port "$1" dest_port
	config_get src "$1" src
	config_get src_ip "$1" src_ip
	config_get src_port "$1" src_port
	config_get_bool counter "$1" counter
	config_get class "$1" class
	config_get name "$1" name

	# Convert configuration into appropriate rule format
	# rule_nfproto function integrated
	[ -z "$family" ] || nfproto="meta nfproto { $(formatListString "$family" ", ") }" || return 1

	# rule_l4proto function integrated
	[ -z "$proto" ] || l4proto="meta l4proto { $(formatListString "$proto" ", ") }" || return 1

	rule_zone dest "$dest" || return 1
	rule_addr dest "$dest_ip" "$family" || return 1
	rule_port dest "$dest_port" "$proto" || return 1
	rule_zone src "$src" || return 1
	rule_addr src "$src_ip" "$family" || return 1
	rule_port src "$src_port" "$proto" || return 1
	rule_device "$device" "$direction" || return 1
	rule_verdict "$class" || return 1

	# Appending the formed rule to the post include file
	[ -z "$daddr$saddr" ] && {
		echo "insert rule inet bakesale static_classify $nfproto $l4proto $oifname $dport $iifname $sport ${counter:+counter} $verdict ${name:+comment \"$name\"}" >>"/tmp/etc/bakesale-post.include"
		return 0
	}
	[ -n "$daddr$saddr" ] && {
		echo "insert rule inet bakesale static_classify $nfproto $l4proto $oifname $daddr $dport $iifname $saddr $sport ${counter:+counter} $verdict ${name:+comment \"$name\"}" >>"/tmp/etc/bakesale-post.include"
	}
	return 0
}

# Main function to create the post include content
create_post_include() {
	local list
	# Variables initialization
	local enabled family proto direction device dest dest_ip dest_port src src_ip src_port counter class name
	local nfproto l4proto oifname daddr dport iifname saddr sport verdict
	local client_hints

	# Check client hints configuration
	config_get_bool client_hints global client_hints 1
	[ "$client_hints" = 1 ] || return 0

	# Add default rule for DSCP to connection tracking mapping
	append_to_file "insert rule inet bakesale static_classify ip dscp != { cs0, cs6, cs7 } iifname != \$wan ip dscp vmap @dscp_ct"

	# Create user-defined sets and rules
	config_foreach create_user_set set   # depreciating in favour of 'ipset' section name
	config_foreach create_user_set ipset # section name consistent with fw4

	config_foreach_reverse create_user_rule rule

	# Create other specific rules
	create_threaded_client_rule || { log error "Failed to create threaded client rule."; return 1; }
	create_threaded_service_rule || { log error "Failed to create threaded service rule."; return 1; }

	create_dscp_mark_rule || { log error "Failed to create dscp mark rule."; return 1; }

	# Logging
	log notice "created post_include"
}

