#!/bin/bash

append_set_if_not_exists() {
    local setName="$1"
    local setType="$2"

    # Check if the set exists in nftables
    nft list set inet bakesale "$setName" &>/dev/null || {
        # If the set does not exist, append the appropriate 'add set' command
        echo "add set inet bakesale $setName { type $setType; flags timeout; }" >> "/tmp/etc/bakesale-pre.include"
    }
}

create_pre_include() {
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
    } >> "/tmp/etc/bakesale-pre.include"

    # Log a notice that the pre_include file has been created
    log notice "created pre_include"
}
