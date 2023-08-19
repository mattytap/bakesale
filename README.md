# DSCP's BakeSale

An nftables based service for applying DSCP classifications to connections, compatible with OpenWrt's firewall4 for dynamically setting DSCP packet marks (this only works in OpenWrt 22.03 and above).

Combined Luci, FW4, SQM, AQM, Cake, DSCP, AutoRate, WireGuard + PBR use case. Currently in development.

## Objective

The main objective of this project, called BakeSale, is to optimize the utilization of OpenWRT Luci’s firewall4 and SQM modules as an alternative to running multiple repos. The focus is on creating a new SQM QoS script for tc commands and leveraging firewall4 to generate nftable entries. Any additional logic required will be implemented through a new init.d service.

In cases where nftable content cannot be generated solely by firewall4, a static nft file will be loaded by the firewall service. Additionally, the SQM script and/or the new service could generate a dynamic nft file if required.

Once the use case is configured and installed, it becomes a part of my standard OpenWRT configuration, making it easy to back up with sysupgrade.

## Installation

Assuming that SQM is already installed and running, you will then need to install the following and then configure /etc/config/sqm to use the new cake_ct script:

```bash
repo="https://raw.githubusercontent.com/mattytap/bakesale/main"
opkg update
opkg install kmod-sched-ctinfo
wget "$repo/usr/lib/sqm/bakesale.qos" -O "/usr/lib/sqm/bakesale.qos"
wget "$repo/usr/lib/sqm/bakesale.qos.help" -O "/usr/lib/sqm/bakesale.qos.help"
wget "$repo/usr/lib/sqm/layer_cake_ct.qos" -O "/usr/lib/sqm/layer_cake_ct.qos"
wget "$repo/usr/lib/sqm/layer_cake_ct.qos.help" -O "/usr/lib/sqm/layer_cake_ct.qos.help"

```

To install the BakeSale use case, please follow these steps:

```bash
repo="https://raw.githubusercontent.com/mattytap/bakesale/main"
wget "$repo/etc/config/bakesale" -O "/etc/config/bakesale"

mkdir -p "/etc/bakesale.d"
wget "$repo/etc/bakesale.d/main.nft" -O "/etc/bakesale.d/main.nft"
wget "$repo/etc/bakesale.d/maps.nft" -O "/etc/bakesale.d/maps.nft"
wget "$repo/etc/bakesale.d/verdicts.nft" -O "/etc/bakesale.d/verdicts.nft"

wget "$repo/etc/hotplug.d/iface/21-bakesale" -O "/etc/hotplug.d/iface/21-bakesale"
wget "$repo/etc/init.d/bakesale" -O "/etc/init.d/bakesale"
chmod +x "/etc/init.d/bakesale"

mkdir -p "/usr/lib/bakesale"
wget "$repo/usr/lib/bakesale/bakesale.sh" -O "/usr/lib/bakesale/bakesale.sh"
wget "$repo/usr/lib/bakesale/pre_include.sh" -O "/usr/lib/bakesale/pre_include.sh"
wget "$repo/usr/lib/bakesale/post_include.sh" -O "/usr/lib/bakesale/post_include.sh"
wget "$repo/usr/lib/bakesale/post_include_user_set.sh" -O "/usr/lib/bakesale/post_include_user_set.sh"
wget "$repo/usr/lib/bakesale/post_include_rules.sh" -O "/usr/lib/bakesale/post_include_rules.sh"
chmod +x "/usr/lib/bakesale/bakesale.sh"
chmod +x "/usr/lib/bakesale/pre_include.sh"
chmod +x "/usr/lib/bakesale/post_include.sh"
chmod +x "/usr/lib/bakesale/post_include_user_set.sh"
chmod +x "/usr/lib/bakesale/post_include_rules.sh"

/etc/init.d/bakesale enable
/etc/init.d/bakesale start

```

## Development Journey - using a repository such as jeverley/dscpclassify

BakeSale is a fork of the excellent [jeverley/dscpclassify](https://github.com/jeverley/dscpclassify) nftables based service for applying DSCP classifications to connections. The BakeSale fork provides a simplified approach focused on IPV4 only, with no sets, no negation, and no error checking or parsing. We owe a lot to their initial work and the foundation DSCPClassify provided.

### DSCPClassify Overview

DSCPClassify is a service for OpenWRT that applies DSCP classification to connections using nftables. It can be used in combination with an SQM QoS script for tc commands, such as layer_cake.qos or simplest.qos, which have been configured to restore ingress DSCP marks from connection tracking. It was designed to work with OpenWRT 22.03 or later and with firewall4, the nftables-based firewall application included with OpenWRT.

DSCPClassify supports three modes of operation, which can be used separately or in combination:

- User rules: Allow you to specify rules for classifying connections in /etc/config/dscpclassify.
- Client DSCP hinting: If enabled, the service will apply the DSCP mark supplied by the client, unless the mark is in the list of ignored DSCP classes.
- Dynamic classification: If enabled, the service will classify connections that don't match user rules based on destination port, destination IP address, and the number of connections from the client to the server.

DSCPClassify can also respect DSCP marks stored in connection tracking by other services, such as netifyd.

### DSCPClassify Installation

To install DSCPClassify, follow these steps:

- Install the required packages
- Enable and start the service

For more details, refer to the [original repository](https://github.com/jeverley/dscpclassify).

### Usage

DSCPClassify is configured through /etc/config/dscpclassify. See [config.example](https://github.com/jeverley/dscpclassify/blob/main/config.example) in the repository for examples of how to configure the service.

### Limitations

- DSCPClassify only supports IPv4 connections.
- The service requires the nftables conntrack module, which is not available on all platforms.

## Acknowledgements and Thanks

We would like to express our gratitude to the authors of OpenWRT SQM (Michael D. Taht, Toke Høiland-Jørgensen, and Sebastian Moeller), as well as the creators of OpenWRT firewall4, jeverley/dscpclassify, lynxthecat/cake-qos-simple, lynxthecat/cake-autorate, and Lochnair/tsping.

Special thanks to [jeverley](https://github.com/jeverley) for their original dscpclassify project which BakeSale is based on.

We also thank stintel for their support of the qoriq platform.
