#!/bin/bash

# File: /usr/lib/bakesale/post_include_user_set.sh

check_uint() {
	[ "$1" -ge 0 ] 2>/dev/null && return 0
	return 1
}

check_duration() {
	echo "$1" | grep -q -E -e "^([1-9][0-9]*[smhd]){1,4}$"
}

parse_set_timeout() {
	[ -n "$timeout" ] || return 0

	[ "$timeout" = 0 ] && {
		flag_timeout=1
		timeout=""
		return 0
	}

	check_uint "$timeout" && {
		flag_timeout=1
		timeout="${timeout}s"
	}

	check_duration "$timeout" || {
		log warning "Set '$name' contains an invalid timeout option"
		return 1
	}

	return 0
}

post_include() {
	echo "$1" >>"/tmp/etc/bakesale-post.include"
}

check_set_against_existing() {
	local name type comment size flags timeout
	local existing_set existing_type

	name="$1"
	existing_set=$(nft -t -j list set inet bakesale "$name" 2>/dev/null) || return 2

	type="$(echo "$2" | sed 's/ \+\. \+/ /g')"
	existing_type="$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.type")"
	if [ -n "$existing_type" ]; then
		[ "$existing_type" = "$type" ] || return 1
	else
		existing_type="$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.type[*]" | tr '\n' ' ' | sed 's/ *$//')"
		[ "$existing_type" = "$type" ] || return 1
	fi

	comment="$3"
	[ "$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.comment")" = "$comment" ] || return 1

	size="$4"
	[ "$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.size")" = "$size" ] || return 1

	flags="$(echo "$5" | sed 's/, \+/ /g')"
	[ "$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.flags[*]" | tr '\n' ' ' | sed 's/ *$//')" = "$flags" ] || return 1

	timeout="$(convert_duration_to_seconds "$6")"
	[ "$(jsonfilter -s "$existing_set" -e "@.nftables[*].set.timeout")" = "$timeout" ] || return 1

	return 0
}

create_user_set() {
	local comment entry element enabled family flags match size name timeout type
	local flag_constant flag_interval flag_timeout auto_merge

	config_get_bool enabled "$1" enabled 1
	[ "$enabled" = 1 ] || return 0

	# Gather all configuration parameters
	config_get comment "$1" comment
	config_get name "$1" name
	config_get family "$1" family ipv4
	config_get match "$1" match
	config_get type "$1" type # allows user to explicity specify the nft set type
	config_get size "$1" maxelem
	config_get timeout "$1" timeout
	config_get_bool flag_constant "$1" constant
	config_get_bool flag_interval "$1" interval
	config_get entry "$1" entry
	config_get element "$1" element # depreciate for naming consistency with fw4 (entry)

	# If element is not null, give a warning
	[ -n "$element" ] && log warning "The user set 'element' option is being depreciated in favour of 'entry' for consistency with fw4"

	# Check set name
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
	if [ -n "$size" ]; then
		if ! [ "$size" -ge 1 ] 2>/dev/null || ! [ "$size" -le 65535 ] 2>/dev/null; then
			log warning "Set '$name' contains an invalid maxelem option"
			return 1
		fi
	fi

	# Check family
	if [ "$family" != "ipv4" ]; then
		log warning "Set contains an invalid family"
		return 1
	fi

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
			type=$(mklist "$type" " . ")
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
		flags="$(mklist "$flags" ", ")"
	fi

	# Check set against existing
	check_set_against_existing "$name" "$type" "$comment" "$size" "$flags" "$timeout" || {
		[ "$?" = 1 ] && post_include "delete set inet bakesale $name"
		post_include "add set inet bakesale $name { type $type; ${timeout:+timeout $timeout;} ${size:+size $size;} ${flags:+flags $flags;} ${auto_merge:+auto-merge;} ${comment:+comment \"$comment\";} }"
	}

	# Add element if not null
	[ -n "$entry$element" ] && echo "add element inet bakesale $name { $(mklist "$entry $element" ", ") }" >>"/tmp/etc/bakesale-post.include"
	return 0
}
