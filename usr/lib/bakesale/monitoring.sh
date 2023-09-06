#!/bin/bash

# Add logging rules for 443 traffic to duiagnose BBC Sounds issues etc
monitor443() {
	# Check for existence of the logging rule in srcnat_wan
	if ! nft list chain inet fw4 srcnat_wan | grep -q 'SNAT to 443 in srcnat_wan:'; then
		nft insert rule inet fw4 srcnat_wan tcp dport 443 log prefix "\"SNAT to 443 in srcnat_wan: \""
	fi

	# Check for existence of the logging rule in srcnat_vpn
	if ! nft list chain inet fw4 srcnat_vpn | grep -q 'SNAT to 443 in srcnat_vpn:'; then
		nft insert rule inet fw4 srcnat_vpn tcp dport 443 log prefix "\"SNAT to 443 in srcnat_vpn: \""
	fi
}

ips() {
	if ! nft list chain inet fw4 reject_from_wan | grep -q 'ip saddr add @banIP:blocklistv4'; then
		nft insert rule inet fw4 reject_from_wan meta nfproto ipv4 iifname { "eth0", "eth5" } log prefix "\"ip saddr add @banIP:blocklistv4 \""
	fi
	log notice "nftables monitor443 rules inserted"
}

config_load bakesale || return 1
config_get_bool MONITOR443 global monitor443 1
(( MONITOR443 )) && { monitor443 || return 1; }
config_get_bool IPS global ips 1
(( IPS )) && { ips || return 1; }
