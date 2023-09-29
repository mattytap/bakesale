#!/bin/bash
trap 'echo "Caught SIGINT, exiting."; exit 1' SIGINT
readonly RDAP_URL="https://rdap.arin.net/registry/ip/"
extract_packets_and_bytes() {
    local COUNTER=${1%% *}
    local PACKETS=${1#*packets }; PACKETS=${PACKETS%% *}
    [[ "$1" =~ bytes[[:space:]]([0-9]+) ]] && local BYTES=${BASH_REMATCH[1]} || local BYTES=""
    echo "$COUNTER $PACKETS $BYTES"
}
echo "Adding routes to vpn_bypass..."
ip route show | grep 'proto static' | grep -v '^default' | awk '{print $1}' | 
while read -r CIDR; do nft add element inet vpn_bypass_analysis vpn_bypass { "$CIDR" }; done
nft list set inet vpn_bypass_analysis tcp_443_net && nft list set inet vpn_bypass_analysis tcp_443

while true; do
    echo "==========================================================================================================="
    echo "Fetching next IP to aggregate..."

    # Call the function to get the IP info
    LINE_WITH_IP=$(nft list set inet vpn_bypass_analysis tcp_443 | grep -m1 '{ [0-9]\+' | sed 's/^.*{ //')
    IP=${LINE_WITH_IP%% *}
    [[ -z "$LINE_WITH_IP" ]] && { echo "tcp_443 set is empty!"; sleep 5; continue; }
    [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || { echo "Invalid IP address format: $IP"; exit 1; }

    # Fetch CIDR for IP
    CIDR_INFO=$(wget -qO- "$RDAP_URL$IP")
    CIDR=$(echo "$CIDR_INFO" | jq -r '.cidr0_cidrs[0].v4prefix + "/" + (.cidr0_cidrs[0].length | tostring)')
    [[ $CIDR =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "Invalid CIDR format: $CIDR"; exit 1; }
    [[ "$CIDR" ]] || { CIDR="${IP}/32"; echo "Error fetching CIDR for $IP. Using /32."; }

    # Extract packets and bytes for the IP
    LINE_WITH_IP=$(nft list set inet vpn_bypass_analysis tcp_443 | grep -m1 '{ [0-9]\+' | sed 's/^.*{ //')
    read -r IPCHECK PACKETS BYTES <<< $(extract_packets_and_bytes "$LINE_WITH_IP")
    [[ "$IP" == "$IPCHECK" ]] || { echo "IP mismatch detected! Try again..."; continue; }
    echo "IP: $IP | Packets: $PACKETS | Bytes: $BYTES"

    # Extract packets and bytes for the CIDR
    LINE_WITH_CIDR=$(nft list set inet vpn_bypass_analysis tcp_443_net | grep -m1 "$CIDR")
    LINE_WITH_CIDR=$(echo "$LINE_WITH_CIDR" | awk -v cidr="$CIDR" '{print substr($0, index($0, cidr))}')
    read -r EXISTING_COUNTER EXISTING_PACKETS EXISTING_BYTES <<< $(extract_packets_and_bytes "$LINE_WITH_CIDR")
    echo "Existing CIDR: $CIDR | Packets: $EXISTING_PACKETS | Bytes: $EXISTING_BYTES"

    # Compute new CIDR counters
    NEW_PACKETS=$(( PACKETS + EXISTING_PACKETS ))
    NEW_BYTES=$(( BYTES + EXISTING_BYTES ))
    echo "Updating CIDR with counters: | Packets $NEW_PACKETS | Bytes $NEW_BYTES"
    [[ -z "$EXISTING_COUNTER" ]] && echo "Proceeding to add a new CIDR element...."

    # Try to add CIDR to tcp_443_net
    nft delete element inet vpn_bypass_analysis tcp_443_net { "$CIDR" } 2> /dev/null
    nft add element inet vpn_bypass_analysis tcp_443_net { "$CIDR" counter packets "$NEW_PACKETS" bytes "$NEW_BYTES" } || {
        echo "Failed to update counters for CIDR $CIDR in tcp_443_net. Adding to Sin Bin."
        nft add element inet vpn_bypass_analysis tcp_sin_bin { "$CIDR" counter packets "$NEW_PACKETS" bytes "$NEW_BYTES" } || {
            echo "Failed to update Sin Bin for CIDR $CIDR."; continue; }; }

    # Archive IP and then delete it from the tcp_443 set
    nft add element inet vpn_bypass_analysis tcp_archive { "$IP" counter packets "$PACKETS" bytes "$BYTES" }
    echo "Archived IP $IP. Deleting from tcp_443 set."
    nft delete element inet vpn_bypass_analysis tcp_443 { "$IP" } || { echo "Failed to delete IP $IP from tcp_443 set."; exit 1; }
done

echo "Script execution complete."
