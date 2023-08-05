#!/bin/bash

# File: /usr/lib/bakesale/pre_include.sh

# Called by: /usr/lib/bakesale/bakesale.sh

create_pre_include() {
    # Define lan and wan using mklist function and add them into bakesale-pre.include
	echo "define lan = { $(mklist "$lan" ", " "\"") }" >> "/tmp/etc/bakesale-pre.include"
	echo "define wan = { $(mklist "$wan" ", " "\"") }" >> "/tmp/etc/bakesale-pre.include"

    # Add new table to bakesale-pre.include
	echo "add table inet bakesale" >> "/tmp/etc/bakesale-pre.include"

    # Check if the threaded_clients set exists and add it into bakesale-pre.include if not
	nft -t list set inet bakesale threaded_clients &>/dev/null
	if [ $? -ne 0 ]; then
		echo "add set inet bakesale threaded_clients { type ipv4_addr . inet_service . inet_proto; flags timeout; }" >> "/tmp/etc/bakesale-pre.include"
	fi

    # Check if the threaded_services set exists and add it into bakesale-pre.include if not
	nft -t list set inet bakesale threaded_services &>/dev/null
	if [ $? -ne 0 ]; then
		echo "add set inet bakesale threaded_services { type ipv4_addr . ipv4_addr . inet_service . inet_proto; flags timeout; }" >> "/tmp/etc/bakesale-pre.include"
	fi

    # Include verdicts.nft and maps.nft into bakesale-pre.include
	echo "include \"/etc/bakesale.d/verdicts.nft\"" >> "/tmp/etc/bakesale-pre.include"
	echo "include \"/etc/bakesale.d/maps.nft\"" >> "/tmp/etc/bakesale-pre.include"

    # Log a notice message
	log notice "created pre_include"
}
