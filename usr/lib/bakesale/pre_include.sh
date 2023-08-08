#!/bin/bash

# File: /usr/lib/bakesale/post_include.sh

# Called by: /usr/lib/bakesale/bakesale.sh

# Variables for paths
BAKESALE_LIB_PATH="/usr/lib/bakesale"
PRE_INCLUDE_PATH="/tmp/etc/bakesale-pre.include"

append_set_if_not_exists() {
    local setName="$1"
    local setType="$2"

    # Check if the set exists in nftables
    nft list set inet bakesale "$setName" &>/dev/null || {
        # If the set does not exist, append the appropriate 'add set' command
        echo "add set inet bakesale $setName { type $setType; flags timeout; }" >> "$PRE_INCLUDE_PATH"
    }
}

create_pre_include() {
    # Ensure that the variables are local
    local lan="$1"
    local wan="$2"

    # Using a block to append multiple lines to 'bakesale-pre.include' for efficiency
    {
        # Define lan and wan based on formatted strings
        echo "define lan = { $(formatListString "$lan" ", " "\"") }"
        echo "define wan = { $(formatListString "$wan" ", " "\"") }"

        # Add the main bakesale table to nftables
        echo "add table inet bakesale"

        # Check for the existence of sets and append creation commands if necessary
        append_set_if_not_exists "threaded_clients" "ipv4_addr . inet_service . inet_proto"
        append_set_if_not_exists "threaded_services" "ipv4_addr . ipv4_addr . inet_service . inet_proto"

        # Include the static nftables DSCP/CT/WMM mappings
        echo "include \"/etc/bakesale.d/verdicts.nft\""
        echo "include \"/etc/bakesale.d/maps.nft\""
    } >> "$PRE_INCLUDE_PATH"

    # Log a notice that the pre_include file has been created
    log notice "created pre_include"
}

