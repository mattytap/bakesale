#!/bin/bash

# File: /usr/lib/bakesale/post_include.sh

# Called by: /usr/lib/bakesale/bakesale.sh

# Source helper scripts
. /usr/lib/bakesale/post_include_user_set.sh
. /usr/lib/bakesale/post_include_rules.sh

config_foreach_reverse() {
	local list

	config_foreach list+=$'\n'"$1" "$2"

	list=$(echo "$list" | sort -r)

	for _ in $list; do
		"$1" "$3"
	done
}

create_threaded_client_rule() {
	local class_bulk threaded_client_min_bytes threaded_client_min_connections

	config_get threaded_client_min_connections global threaded_client_min_connections 10

	if ! ([ "$threaded_client_min_connections" -ge 0 ] 2>/dev/null) || [ "$threaded_client_min_connections" -lt 2 ]; then
		log error "Global option 'threaded_client_min_connections' contains an invalid value"
		return 1
	fi

	config_get threaded_client_min_bytes global threaded_client_min_bytes 10000

	if ! ([ "$threaded_client_min_bytes" -ge 0 ] 2>/dev/null) || [ "$threaded_client_min_bytes" = 0 ]; then
		log error "Global option 'threaded_client_min_bytes' contains an invalid value"
		return 1
	fi

	config_get class_bulk global class_bulk le

	class_bulk="$(check_class "$class_bulk")" || {
		log error "Global option 'class_bulk' contains an invalid DSCP class"
		return 1
	}

	# Generate and append rules to bakesale-post.include
	echo "add rule inet bakesale established_connection meter tc_detect { ip daddr . th dport . meta l4proto timeout 5s limit rate over $((threaded_client_min_connections - 1))/minute } add @threaded_clients { ip daddr . th dport . meta l4proto timeout 30s }" >>"/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_client meter tc_orig_bulk { ip saddr . th sport . meta l4proto timeout 5m limit rate over $((threaded_client_min_bytes - 1)) bytes/hour } update @threaded_clients { ip saddr . th sport . meta l4proto timeout 5m } goto ct_set_$class_bulk" >>"/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_client_reply meter tc_reply_bulk { ip daddr . th dport . meta l4proto timeout 5m limit rate over $((threaded_client_min_bytes - 1)) bytes/hour } update @threaded_clients { ip daddr . th dport . meta l4proto timeout 5m } goto ct_set_$class_bulk" >>"/tmp/etc/bakesale-post.include"
}

create_threaded_service_rule() {
	local class_high_throughput threaded_service_min_bytes threaded_service_min_connections

	config_get threaded_service_min_connections global threaded_service_min_connections 3

	if ! echo "$threaded_service_min_connections" | grep -qE "^[0-9]+$" || [ "$threaded_service_min_connections" -lt 2 ]; then
		log error "Global option 'threaded_service_min_connections' contains an invalid value"
		return 1
	fi

	config_get threaded_service_min_bytes global threaded_service_min_bytes 1000000

	if ! echo "$threaded_service_min_bytes" | grep -qE "^[0-9]+$" || [ "$threaded_service_min_bytes" = 0 ]; then
		log error "Global option 'threaded_service_min_bytes' contains an invalid value"
		return 1
	fi

	config_get class_high_throughput global class_high_throughput af13

	class_high_throughput="$(echo "$class_high_throughput" | tr 'A-Z' 'a-z')"
	case "$class_high_throughput" in
	af11 | af12 | af13 | af21 | af22 | af23 | af31 | af32 | af33 | af41 | af42 | af43 | cs1 | cs2 | cs3 | cs4 | cs5 | cs6 | cs7 | be | ef) true ;;
	*) log error "Global option 'class_high_throughput' contains an invalid DSCP class"; return 1 ;;
	esac

	# Generate and append rules to bakesale-post.include
	echo "add rule inet bakesale established_connection meter ts_detect { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 5s limit rate over $((threaded_service_min_connections - 1))/minute } add @threaded_services { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 30s }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service ct original bytes < $threaded_service_min_bytes return" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service update @threaded_services { ip saddr . ip daddr and 255.255.255.0 . th dport . meta l4proto timeout 5m }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service goto ct_set_$class_high_throughput" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply ct reply bytes < $threaded_service_min_bytes return" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply update @threaded_services { ip daddr . ip saddr and 255.255.255.0 . th sport . meta l4proto timeout 5m }" >> "/tmp/etc/bakesale-post.include"
	echo "add rule inet bakesale threaded_service_reply goto ct_set_$class_high_throughput" >> "/tmp/etc/bakesale-post.include"
}

create_dscp_mark_rule() {
	local wmm

	config_get_bool wmm global wmm 0

	if [ "$wmm" = 1 ]; then
		echo "add rule inet bakesale postrouting oifname \$lan ct mark and \$ct_dscp vmap @ct_wmm" >> "/tmp/etc/bakesale-post.include"
	fi
	echo "add rule inet bakesale postrouting ct mark and \$ct_dscp vmap @ct_dscp" >> "/tmp/etc/bakesale-post.include"
}

create_user_rule() {
	local enabled family proto direction device dest dest_ip dest_port src src_ip src_port counter class name
	local nfproto l4proto oifname daddr dport iifname saddr sport verdict

	config_get_bool enabled "$1" enabled 1
	[ "$enabled" = 1 ] || return 0

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

	# rule_nfproto function integrated
	[ -z "$family" ] || nfproto="meta nfproto { $(mklist "$family" ", ") }" || return 1

	# rule_l4proto function integrated
	[ -z "$proto" ] || l4proto="meta l4proto { $(mklist "$proto" ", ") }" || return 1

	rule_zone dest "$dest" || return 1
	rule_addr dest "$dest_ip" "$family" || return 1
	rule_port dest "$dest_port" "$proto" || return 1
	rule_zone src "$src" || return 1
	rule_addr src "$src_ip" "$family" || return 1
	rule_port src "$src_port" "$proto" || return 1
	rule_device "$device" "$direction" || return 1
	rule_verdict "$class" || return 1

	[ -z "$daddr$saddr" ] && {
		echo "insert rule inet bakesale static_classify $nfproto $l4proto $oifname $dport $iifname $sport ${counter:+counter} $verdict ${name:+comment \"$name\"}" >>"/tmp/etc/bakesale-post.include"
		return 0
	}
	[ -n "$daddr$saddr" ] && {
		echo "insert rule inet bakesale static_classify $nfproto $l4proto $oifname $daddr $dport $iifname $saddr $sport ${counter:+counter} $verdict ${name:+comment \"$name\"}" >>"/tmp/etc/bakesale-post.include"
	}
	return 0
}

create_post_include() {
	local list
	local enabled family proto direction device dest dest_ip dest_port src src_ip src_port counter class name
	local nfproto l4proto oifname daddr dport iifname saddr sport verdict
    local client_hints

	config_get_bool client_hints global client_hints 1
	[ "$client_hints" = 1 ] || return 0

	echo "insert rule inet bakesale static_classify ip dscp != { cs0, cs6, cs7 } iifname != \$wan ip dscp vmap @dscp_ct" >>"/tmp/etc/bakesale-post.include"

	config_foreach create_user_set set   # depreciating in favour of 'ipset' section name for consistency with fw4
	config_foreach create_user_set ipset # section name consistent with fw4
	config_foreach_reverse create_user_rule rule

	create_threaded_client_rule || return 1
	create_threaded_service_rule || return 1

	create_dscp_mark_rule || return 1

	log notice "created post_include"
}
