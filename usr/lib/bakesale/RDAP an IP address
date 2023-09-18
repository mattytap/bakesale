#!/bin/bash

# For each IP in ips_blocklist_wan, get its RDAP CIDR and add to wan_ips_blocklist_net, then remove the IP
nft list set inet fw4 ips_blocklist_wan | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | while read IP; do
    # Retrieve CIDR for IP using RDAP
    CIDR=$(wget -qO- https://rdap.arin.net/registry/ip/$IP | jq -r '.startAddress + "-" + .endAddress')
echo $CIDR
    # Check if CIDR was retrieved successfully
    if [[ ! -z $CIDR ]]; then
        # Add CIDR to wan_ips_blocklist_net
        nft add element inet fw4 wan_ips_blocklist_net { $CIDR }

        # Remove IP from ips_blocklist_wan
        nft delete element inet fw4 ips_blocklist_wan { $IP }
    fi
done

