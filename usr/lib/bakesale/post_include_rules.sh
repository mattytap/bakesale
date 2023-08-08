#!/bin/bash

# Paths
LIB_BAKESALE="/usr/lib/bakesale"

# Sets the oifname rule based on provided interface names.
rule_oifname() {
    [[ -n "$1" ]] || return 0
    echo "oifname { $(formatListString "$1" ", " "\"") }"
}

# As above, but for iifname.
rule_iifname() {
    [[ -n "$1" ]] || return 0
    echo "iifname { $(formatListString "$1" ", " "\"") }"
}

rule_zone() {
	local device dev direction="$1" zone_name="$2"

	[[ -n "$zone_name" ]] || return 0

	dev="$(fw4 -q zone "$zone_name" | sort -u)"
	[[ -n "$dev" ]] && device="$dev" || {
		log warning "Rule '$name' contains an invalid $direction zone"
		return 1
	}

	case "$direction" in
	src) rule_iifname "$device" ;;
	dest) rule_oifname "$device" ;;
	*)
		log error "Invalid direction for zone function"
		return 1
		;;
	esac
}

# Function to generate address rules
# $1: The direction of traffic (src/dest)
# $2: IP or IP set
# $3: The IP family (ipv4)
rule_addr() {
	local rule xaddr ipv4="" ipset="" ipv4_negate="" ipset_negate=""

	# Set xaddr based on the direction of traffic
	case "$1" in
	src) xaddr="saddr" ;;
	dest) xaddr="daddr" ;;
	*)
		log error "Invalid direction for addr function"
		return 1
		;;
	esac

	# Return if second argument is empty
	[[ -n "$2" ]] || return 0

	# Log warning and return 1 if third argument is not ipv4
	[[ -n "$3" && "$3" != "ipv4" ]] && {
		log warning "Rule '$name' contains an invalid family"
		return 1
	}

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

	[[ -n "$ipv4" ]] && rule="ip $xaddr { $(formatListString "$ipv4" ", ") }"
	[[ -n "$ipv4_negate" ]] && rule="$rule ip $xaddr != { $(formatListString "$ipv4_negate" ", ") }"
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
	return 0
}

# Function to generate port rules
# $1: The direction of traffic (src/dest)
# $2: Port or range of ports
# $3: The protocol (tcp/udp)
rule_port() {
	local port port_negate rule xport

	# Set xport based on the direction of traffic
	case "$1" in
	src) xport="sport" ;;
	dest) xport="dport" ;;
	*)
		log error "Invalid direction for port function"
		return 1
		;;
	esac

	# Return if second argument is empty
	[[ -n "$2" ]] || return 0

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

	[[ -n "$port" ]] && rule="th $xport { $(formatListString "$port" ", ") }"

	[[ -n "$port_negate" ]] && rule="$rule th $xport != { $(formatListString "$port_negate" ", ") }"

	eval "$xport"='$rule'
	return 0
}

# Function to generate device rules
# $1: The device name
# $2: The direction of traffic (in/out)
rule_device() {
  # Exit function if there are no arguments
	[[ -n "$1" ]] || return 0

  # Log a warning and return 1 if the second argument is empty
	[ -n "$2" ] || {
		log warning "Rules must use the device and direction options in conjunction"
		return 1
	}

	case "$2" in
	in) rule_iifname "$1" ;;
	out) rule_oifname "$1" ;;
	*)
		log warning "The direction rule option must contain either 'in' or 'out'"
		return 1
		;;
	esac
}

check_class() {
	local class

	class="${1,,}"

	case "$class" in
	le) [[ "$2" = "var" ]] && class="lephb" ;;
	be | df) class="cs0" ;;
	cs0 | cs1 | af11 | af12 | af13 | cs2 | af21 | af22 | af23 | cs3 | af31 | af32 | af33 | cs4 | af41 | af42 | af43 | cs5 | va | ef | cs6 | cs7) true ;;
	*) return 1 ;;
	esac

	echo "$class"
	return 0
}

# Function to generate rule_verdict
# $1: DSCP class
# $2: Used to set 'le' class to 'lephb'
rule_verdict() {
	local class

	[[ -n "$1" ]] || {
		log warning "Rule is missing the DSCP class option"
		return 1
	}

	class="$(check_class "$1")" || {
		log warning "Rule '$name' contains an invalid DSCP class"
		return 1
	}

	verdict="goto ct_set_$class"
}
