#!/bin/bash

# File: /usr/lib/bakesale/post_include_user_set.sh

check_duration() {
	[[ "$1" =~ ^([1-9][0-9]*[smhd]){1,4}$ ]]
}

parse_set_timeout() {
	[[ -z "$timeout" ]] && return 0

	[ "$timeout" = 0 ] && {
		flag_timeout=1
		timeout=""
		return 0
	}

	validate_integer "$timeout" && {
		flag_timeout=1
		timeout="${timeout}s"
	}

	check_duration "$timeout" || {
		log warning "Set '$name' contains an invalid timeout option"
		return 1
	}
}

check_set_against_existing() {
	local existing_set existing_type

	existing_set=$(nft -t -j list set inet bakesale "$1" 2>/dev/null) || return 2

	extract_json() {
		jsonfilter -s "$existing_set" -e "$1" | tr '\n' ' ' | sed 's/ *$//'
	}

	[[ "$2" == "$(extract_json '@.nftables[*].set.type')" ]] || return 1
	[[ "$3" == "$(extract_json '@.nftables[*].set.comment')" ]] || return 1
	[[ "$4" == "$(extract_json '@.nftables[*].set.size')" ]] || return 1
	[[ "$5" == "$(extract_json '@.nftables[*].set.flags[*]')" ]] || return 1

	timeout="$(convert_duration_to_seconds "$6")"
	[[ "$timeout" == "$(extract_json '@.nftables[*].set.timeout')" ]] || return 1
}

fetch_config() {
	local config_name="$1"

	config_get_bool enabled "$config_name" enabled 1

	# Gather configuration parameters
	config_get comment "$config_name" comment
	config_get name "$config_name" name
	config_get family "$config_name" family ipv4
	config_get match "$config_name" match
	config_get type "$config_name" type # allows user to explicity specify the nft set type
	config_get size "$config_name" maxelem
	config_get timeout "$config_name" timeout
	config_get_bool flag_constant "$config_name" constant
	config_get_bool flag_interval "$config_name" interval
	config_get entry "$config_name" entry
	config_get element "$config_name" element # depreciate for naming consistency with fw4 (entry)
}

process_rule() {

	[[ "$enabled" == 1 ]] || return 0

	[[ -n "$element" ]] && log warning "The user set 'element' option is being deprecated in favor of 'entry' for consistency with fw4"

	case "$name" in
	"")
		log warning "Set is missing the name option"
		return 1
		;;
	threaded_clients | threaded_services)
		log warning "Sets cannot overwrite built-in bakesale sets"
		return 1
		;;
	esac

	# Check set size
	[[ -n "$size" && ($size -lt 1 || $size -gt 65535) ]] && {
		log warning "Set '$name' contains an invalid maxelem option"
		return 1
	}

	# Check family
	[[ "$family" != "ipv4" ]] && log warning "Set contains an invalid family" && return 1

	# Parse set type
	if [ -z "$type" ]; then
		if [ -z "$match" ]; then
			type="${family}_addr"
		else
			log warning "The match set option functionality is not yet fully implemented for user sets"
			for i in $match; do
				case "$i" in
				src_* | dest_*) true ;;
				*)
					log warning "Set '$name' contains an invalid match option"
					return 1
					;;
				esac
				case "$i" in
				*_ip) type="$type ${family}_addr" ;;
				*_mac) type="$type ether_addr" ;;
				*_port) type="$type inet_service" ;;
				*_net)
					type="$type ${family}_addr"
					flag_interval=1
					;;
				*)
					log warning "Set '$name' contains an invalid match option"
					return 1
					;;
				esac
			done
			type=$(format_to_list_string "$type" " . ")
		fi
	fi

	# Parse set timeout
	parse_set_timeout || return 1

	# Parse set flags
	[ "$flag_constant" = 1 ] && {
		flags="$flags constant"
	}
	[ "$flag_interval" = 1 ] && {
		flags="$flags interval"
		auto_merge=1
	}
	[ "$flag_timeout" = 1 ] && {
		flags="$flags timeout"
	}
	if [ -n "$flags" ]; then
		flags="$(format_to_list_string "$flags" ", ")"
	fi

	# Check set against existing
	check_set_against_existing "$name" "$type" "$comment" "$size" "$flags" "$timeout" || {
		[ "$?" = 1 ] && append_to_file "delete set inet bakesale $name"
		append_to_file "add set inet bakesale $name { type $type; ${timeout:+timeout $timeout;} ${size:+size $size;} ${flags:+flags $flags;} ${auto_merge:+auto-merge;} ${comment:+comment \"$comment\";} }"
	}

	# Add element if not null
	[ -n "$entry$element" ] && append_to_file "add element inet bakesale $name { $(format_to_list_string "$entry $element" ", ") }"
	return 0
}

create_user_set() {
    local config_name="$1"

    fetch_config "$config_name"
    process_rule
}
