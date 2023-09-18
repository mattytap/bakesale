#!/bin/bash

# Initialize the table
nft delete table inet vpn_bypass_analysis
nft add table inet vpn_bypass_analysis

# Adding the sets
nft add set inet vpn_bypass_analysis vpn_bypass '{ type ipv4_addr; flags interval,timeout; counter; }'
nft add set inet vpn_bypass_analysis tcp_443_net '{ type ipv4_addr; flags interval,timeout; counter; }'
nft add set inet vpn_bypass_analysis tcp_443 '{ type ipv4_addr; flags dynamic,timeout; counter; comment "ingress tcp 443"; }'

# Create the prerouting chain and its rules
nft add chain inet vpn_bypass_analysis prerouting '{ type filter hook prerouting priority filter; policy accept; }'
nft add rule inet vpn_bypass_analysis prerouting 'ip daddr 192.168.240.101 tcp sport 443 ip saddr @vpn_bypass counter'
nft add rule inet vpn_bypass_analysis prerouting 'ip daddr 192.168.240.101 tcp sport 443 ip saddr @tcp_443_net counter'
nft add rule inet vpn_bypass_analysis prerouting 'ip daddr 192.168.240.101 tcp sport 443 ip saddr != @vpn_bypass ip saddr != @tcp_443_net counter update @tcp_443 { ip saddr }'

# Static Routes
ip route show | grep 'proto static' | grep -v '^default' | awk '{print $1}' | while read -r CIDR; do nft add element inet vpn_bypass_analysis vpn_bypass { $CIDR }; done

# Display the table for verification
nft list table inet vpn_bypass_analysis | sed '/elements = {/,/}/{s/,\([^$]\)/,\n\t\t            \1/g;}' | sed 's/ c/ \tc/'