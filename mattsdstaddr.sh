#!/bin/bash

# Pre-check for tcpdump
if ! tcpdump --version >/dev/null 2>&1; then
    echo "Error: tcpdump not found or not executable."
    exit 1
fi

REVERSE_DNS=1 # Default is ON
EXCLUDES=()

# Parse options
while getopts "de:" opt; do
    case $opt in
    d)
        REVERSE_DNS=0 # Turn off reverse DNS
        ;;
    e)
        EXCLUDES+=("$OPTARG")
        ;;
    *)
        echo "Usage: $0 [-d] [-e subnet]..."
        exit 1
        ;;
    esac
done

# Construct tcpdump exclude filter
EXCLUDE_FILTER=""
for subnet in "${EXCLUDES[@]}"; do
    EXCLUDE_FILTER="$EXCLUDE_FILTER and not net $subnet"
done

# Function to monitor a specific interface
monitor_interface() {
    local interface=$1
    local startX=0
    if [ "$interface" == "eth0" ]; then
        startX=41
    fi
    local filter="tcp and not host 192.168.240.101 and port 443 $EXCLUDE_FILTER"

    tcpdump -nn -i "$interface" "$filter" |
        awk -v startX="$startX" -v reverse_dns="$REVERSE_DNS" -F" " '
    function get_dns(ip) {
        if (reverse_dns == 0) return "";
        cmd = "nslookup " ip " 2>&1"
        while (cmd | getline line) {
            if (line ~ /name = /) {
                split(line, parts, "=");
                dns = parts[2];
                sub(/^ /, "", dns);  # remove leading space
                return dns;
            }
        }
        close(cmd)
        return "";  # Return empty if no DNS found or error occurred
    }

    {
        ip = ""
        if ($3 ~ /\.443$/) {
            split($3, src, ".");
            ip = src[1] "." src[2] "." src[3] "." src[4];
        }
        else if ($5 ~ /\.443$/) {
            split($5, dest, ".");
            ip = dest[1] "." dest[2] "." dest[3] "." dest[4];
        }
        ips[ip]++;
        if (ip != "" && !(ip in dns_cache)) {
            dns_cache[ip] = get_dns(ip);
        }

        count++;
        if (count % 10 == 0) {  
            system("clear");  
            for (i in ips) {
                # Formatting for Interface 1
                printf "%-15s %-40s: %6d", i, dns_cache[i], ips[i];
                
                # Check if there is a corresponding IP for Interface 2
                if (i in ips_eth0) {
                    printf "    %-15s %-40s: %6d", i, dns_cache_eth0[i], ips_eth0[i];
                }
                print "";  # Print a newline character
            }
        }
    }'
}

# Start monitoring both interfaces in the background
monitor_interface br-swlan &
monitor_interface eth0 &

# Wait for both processes to finish
wait
