#!/bin/bash

# Paths
LIB_BAKESALE="/usr/lib/bakesale"

rule_oifname() {
    [[ -z "$1" ]] && return 0
    echo "oifname { $(format_to_list_string "$1", ", ", "\"") }"
}

rule_iifname() {
    [[ -z "$1" ]] && return 0
    echo "iifname { $(format_to_list_string "$1", ", ", "\"") }"
}

rule_zone() {
	local device dev direction="$1" zone_name="$2"
	[[ -z "$zone_name" ]] && return 0

	dev="$(fw4 -q zone "$zone_name" | sort -u)"
	[[ -z "$dev" ]] && log warning "Rule '$name' contains an invalid $direction zone" && return 1

	[[ "$direction" == "src" ]] && rule_iifname "$device"
	[[ "$direction" == "dest" ]] && rule_oifname "$device"
}

rule_addr() {
	local rule xaddr ipv4="" ipset="" ipv4_negate="" ipset_negate=""

	[[ "$1" == "src" ]] && xaddr="saddr"
	[[ "$1" == "dest" ]] && xaddr="daddr"

	[[ -z "$2" ]] && return 0

	[[ "$3" && "$3" != "ipv4" ]] && log warning "Rule '$name' contains an invalid family" && return 1

	# Iterate over IPs or IP sets
	for i in $2; do
		# If IP matches regex, add to the appropriate list
		if [[ "$i" =~ ^!?(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9])[.]){3}(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9]))(/([0-9]|[12][0-9]|3[0-2]))?$ ]]; then
			case "$i" in
			"!"*) ipv4_negate="$ipv4_negate ${i#*!}" ;;
			*) ipv4="$ipv4 $i" ;;
			esac
			continue
		fi

		# If IP set matches regex, add to the appropriate list
		echo "$i" | grep -q -E -e "^!?@\w+$" && {
			case "$i" in
			"!"*) ipset_negate="$ipset_negate ${i#*!}" ;;
			*) ipset="$ipset $i" ;;
			esac
			continue
		}
		return 1
	done

	[[ $(echo "$ipset" | wc -w) -gt 1 || $(echo "$ipset_negate" | wc -w) -gt 1 ]] && {
		log warning "Rules must not contain more than one set for the $1_ip option"
		return 1
	}

	[[ -n "$ipv4" ]] && rule="ip $xaddr { $(format_to_list_string "$ipv4" ", ") }"
	[[ -n "$ipv4_negate" ]] && rule="$rule ip $xaddr != { $(format_to_list_string "$ipv4_negate" ", ") }"
	[[ -n "$ipset$ipset_negate" ]] && {
	case "$3" in
		ipv4)
			[[ -n "$ipset" ]] && rule="$rule ip $xaddr $ipset"
			[[ -n "$ipset_negate" ]] && rule="$rule ip $xaddr != $ipset_negate"
			;;
		*)
			log warning "Rules must contain the family option when a set is present in the $1_ip option"
			return 1
			;;
	esac
	}

	eval "$xaddr"='$rule'
}

rule_port() {
	local port port_negate rule xport

	[[ "$1" == "src" ]] && xport="sport"
	[[ "$1" == "dest" ]] && xport="dport"

	[[ -z "$2" ]] && return 0

	# This is the code moved from parse_rule_ports function
	for i in $2; do
		# Return 1 if port doesn't match regex
		echo "$i" | grep -q -E -e "^!?[1-9][0-9]*(-[1-9][0-9]*)?$" || return 1
		case "$i" in
		"!"*) port_negate="$port_negate ${i#*!}" ;;
		*) port="$port $i" ;;
		esac
	done

	# Validate protocol
	for proto in $3; do
		[[ "$proto" =~ ^(tcp|udp)$ ]] || {
			log warning "Rules cannot combine a $1_port with protocols other than 'tcp' or 'udp'"
			return 1
		}
	done

	[[ -n "$port" ]] && rule="th $xport { $(format_to_list_string "$port" ", ") }"

	[[ -n "$port_negate" ]] && rule="$rule th $xport != { $(format_to_list_string "$port_negate" ", ") }"

	eval "$xport"='$rule'
}

rule_device() {
	[[ -z "$1" ]] && return 0

	[[ -z "$2" ]] && log warning "Rules must use the device and direction options together" && return 1

	[[ "$2" == "in" ]] && rule_iifname "$1"
	[[ "$2" == "out" ]] && rule_oifname "$1"
}

rule_target() {
	# Function to generate the 'goto target' based on DSCP class
	# $1: DSCP class
	# $2: Used to set 'le' class to 'lephb'
	local class="${1,,}" # force lower case

	# Validate the DSCP class option
	[[ -z "$1" ]] && log warning "Missing DSCP class option in the rule" && return 1

	case "$class" in
	le) [[ "$2" = "var" ]] && class="lephb" ;;
	be | df) class="cs0" ;;
	cs0 | cs1 | af11 | af12 | af13 | cs2 | af21 | af22 | af23 | cs3 | af31 | af32 | af33 | cs4 | af41 | af42 | af43 | cs5 | va | ef | cs6 | cs7) ;; # Valid classes, do nothing
	*)
		log warning "Rule '$name' contains an invalid DSCP class"
		return 1
		;;
	esac

	target="goto ct_set_$class"
}
