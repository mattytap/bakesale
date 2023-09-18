#!/bin/bash
TMP_UPTIME_FILE="/tmp/.previous_uptime"

# Initialize the PREVIOUS_UPTIME file if it doesn't exist
if [[ ! -f $TMP_UPTIME_FILE ]]; then
    awk '{print $1}' /proc/uptime > "$TMP_UPTIME_FILE"
fi

timestamp() {
    local current_uptime=$(awk '{print $1}' /proc/uptime)
    local previous_uptime=$(cat "$TMP_UPTIME_FILE")
    local elapsed_time=$(awk -v cur="$current_uptime" -v prev="$previous_uptime" 'BEGIN {printf "%.2f", cur - prev}')
    
    # Store the current uptime for the next call.
    echo "$current_uptime" > "$TMP_UPTIME_FILE"

    # Only display if elapsed_time is greater than 0.03
    if (( $(awk 'BEGIN {if ('$elapsed_time' > 0.03) print "1"; else print "0"}') )); then
        echo "$elapsed_time s"
    else
      echo "      "  # six spaces
    fi
}

extract_packets_and_bytes() {
    local LINE=$1

    # Counter
    local COUNTER=${LINE}
    COUNTER=${COUNTER%% *}

    # Packets
    local PACKETS=${LINE#*packets }
    PACKETS=${PACKETS%% *}

    # Bytes
    local BYTES=${LINE#*bytes }
    if [[ "$BYTES" =~ "," ]]; then
        BYTES=${BYTES%%,*}
    else
        BYTES=${BYTES%% *}
    fi

    echo "$COUNTER $PACKETS $BYTES"
}

# Function to refresh LINE_WITH_IP
refresh_ip_info() {
    NFT_OUTPUT=$(nft list set inet vpn_bypass_analysis tcp_443)
    LINE_WITH_IP=$(echo "$NFT_OUTPUT" | grep -m1 '{ [0-9]\+')
    LINE_WITH_IP=${LINE_WITH_IP#*'{ '}

    # Exit condition if no matching line is found
    if [[ -z "$LINE_WITH_IP" ]]; then
        echo "$(timestamp) tcp_443 set is empty!"
        exit 1
    else
        echo "$(timestamp) tcp_443: $LINE_WITH_IP"
    fi

    # Extract the IP
    IP=${LINE_WITH_IP%% *}
}

echo "$(timestamp) Adding static routes to vpn_bypass set..."
ip route show | grep 'proto static' | grep -v '^default' | awk '{print $1}' | while read -r CIDR; do
    nft add element inet vpn_bypass_analysis vpn_bypass { "$CIDR" }
done

nft list set inet vpn_bypass_analysis tcp_443_net
nft list set inet vpn_bypass_analysis tcp_443

while true; do
    echo "$(timestamp) ==========================================================================================================="
    echo "$(timestamp) Fetching next IP to aggregate..."

    # Call the function to get the IP info
    refresh_ip_info

    # Fetch CIDR for IP
    # ... (rest of your code to fetch CIDR, process, etc.)

    # Fetch CIDR for IP
    CIDR_INFO=$(wget -qO- "https://rdap.arin.net/registry/ip/$IP")
    CIDR=$(echo "$CIDR_INFO" | jq -r '.cidr0_cidrs[0].v4prefix + "/" + (.cidr0_cidrs[0].length | tostring)')

    # If jq extraction fails
    if [[ -z "$CIDR" ]]; then
        CIDR="${IP}/32"
        echo "$(timestamp) Error fetching CIDR for $IP. Using /32."
    else
        echo "$(timestamp) Fetched $CIDR for $IP."
    fi

    # At the end of your processing for each IP, you can refresh the IP info:
    refresh_ip_info

    # Extract packets and bytes for the IP
    read -r IPCHECK PACKETS BYTES <<< $(extract_packets_and_bytes "$LINE_WITH_IP")
    
    if [[ "$IP" != "$IPCHECK" ]]; then
        echo "$(timestamp) IP mismatch detected! Exiting..."
        exit 1
    fi
    echo "$(timestamp) $IP $PACKETS $BYTES"

    echo "$(timestamp) Processing $IP with CIDR $CIDR counter $PACKETS, bytes $BYTES"

    # Update the tcp_443_net set
    echo "$(timestamp) Fetching any existing CIDR from tcp_443_net..."
    NFT_OUTPUT=$(nft list set inet vpn_bypass_analysis tcp_443_net)
    echo "$(timestamp) Looking for CIDR: $CIDR"
    LINE_WITH_CIDR=$(echo "$NFT_OUTPUT" | grep -m1 "$CIDR")
    LINE_WITH_CIDR=$(echo "$LINE_WITH_CIDR" | awk -v cidr="$CIDR" '{print substr($0, index($0, cidr))}')

    if [[ -n "$LINE_WITH_CIDR" ]]; then
        echo "$(timestamp) Existing CIDR line: $LINE_WITH_CIDR"
    fi

    # Extract packets and bytes
    read -r EXISTING_COUNTER EXISTING_PACKETS EXISTING_BYTES <<< $(extract_packets_and_bytes "$LINE_WITH_CIDR")

    if [[ -n "$EXISTING_COUNTER" ]]; then
        echo "$(timestamp) $EXISTING_COUNTER $EXISTING_PACKETS $EXISTING_BYTES"
        echo "$(timestamp) Existing counter detected for $CIDR. Updating values..."
    fi

    # If counter data is present, add those values to the current packets and bytes.
    if [[ -n "$EXISTING_PACKETS" ]]; then
        echo "$(timestamp) Adding existing packets ($EXISTING_PACKETS) to current packets ($PACKETS)."
        PACKETS=$(( PACKETS + EXISTING_PACKETS ))
    fi

    if [[ -n "$EXISTING_BYTES" ]]; then
        echo "$(timestamp) Adding existing bytes ($EXISTING_BYTES) to current bytes ($BYTES)."
        BYTES=$(( BYTES + EXISTING_BYTES ))
    fi

    if [[ -n "$EXISTING_COUNTER" ]]; then
        nft delete element inet vpn_bypass_analysis tcp_443_net { "$CIDR" } || {
            echo "$(timestamp) Failed to delete existing counter for CIDR $CIDR from tcp_443_net."
            exit 1
        }
    else
        echo "$(timestamp) No existing counter detected for $CIDR. Proceeding to add a new one..."
    fi

    echo "$(timestamp) Updating counters for CIDR ($CIDR) with packets ($PACKETS) and bytes ($BYTES)."
    nft add element inet vpn_bypass_analysis tcp_443_net { "$CIDR" counter packets "$PACKETS" bytes "$BYTES" } || {
        echo "$(timestamp) Failed to update counters for CIDR $CIDR in tcp_443_net."
        continue
    }

    echo "$(timestamp) Deleting IP $IP from tcp_443 set."
    nft delete element inet vpn_bypass_analysis tcp_443 { "$IP" } || {
        echo "$(timestamp) Failed to delete IP $IP from tcp_443 set."
        exit 1
    }
done

echo "$(timestamp) Script execution complete."
