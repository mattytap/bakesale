# BakeSale

Bits and pieces related to OpenWrt deployments

## Installation

Assuming that SQM is already installed and running, you will then need to install the following and then configure /etc/config/sqm to use the new cake_ct script:

```bash
repo="https://raw.githubusercontent.com/mattytap/bakesale/mattytap"

mkdir -p "/usr/lib/bakesale"
mkdir -p "/usr/libexec/collectd"
mkdir -p "/usr/share/nftables.d/table-pre"

# Download files using wget
wget -O "/usr/lib/bakesale/dns_cache_dump.s" "$repo/usr/lib/bakesale/dns_cache_dump.sh"
wget -O "/usr/lib/bakesale/drop_monitor.sh" "$repo/usr/lib/bakesale/drop_monitor.sh"
wget -O "/usr/lib/bakesale/monitoring.sh" "$repo/usr/lib/bakesale/monitoring.sh"
wget -O "/usr/lib/bakesale/tcp_443_initialise.sh" "$repo/usr/lib/bakesale/tcp_443_initialise.sh"
wget -O "/usr/lib/bakesale/tcp_443_monitor.sh" "$repo/usr/lib/bakesale/tcp_443_monitor.sh"
wget -O "/usr/lib/bakesale/tcp_443_net_update.sh" "$repo/usr/lib/bakesale/tcp_443_net_update.sh"
chmod +x "/usr/lib/bakesale"/*

# overwrites openwrt - check beforehand for any openwrt updates to these files
wget -O "/usr/share/collectd/types.db" "$repo/usr/share/collectd/types.db"
wget -O "/usr/share/nftables.d/table-pre/nft-wan.nft" "$repo/usr/share/nftables.d/table-pre/nft-wan.nft"

# statistics graph definitions
dir="/www/luci-static/resources/statistics/rrdtool/definitions"
wget -O "$dir/autorate.js" "$repo$dir/autorate.js"
wget -O "$dir/nft.js" "$repo$dir/nft.js"
wget -O "$dir/ping.js" "$repo$dir/ping.js"
wget -O "$dir/sqm.js" "$repo$dir/sqm.js"
wget -O "$dir/sqmcake.js" "$repo$dir/sqmcake.js"
wget -O "$dir/../../rrdtool.js" "$repo$dir/../../rrdtool.js"

# collectd exec scripts
wget -O "/usr/libexec/collectd/autorate_collectd.sh" "$repo/usr/libexec/collectd/autorate_collectd.sh"
wget -O "/usr/libexec/collectd/nft_collectd.sh" "$repo/usr/libexec/collectd/nft_collectd.sh"
wget -O "/usr/libexec/collectd/sqm_collectd.sh" "$repo/usr/libexec/collectd/sqm_collectd.sh"
chmod +x "/usr/libexec/collectd"/*

# nft-syn_flood service to extract data securely from nftables for statistics
wget -O "/etc/init.d/nft-syn_flood" "$repo/etc/init.d/nft-syn_flood"
chmod +x "/etc/init.d/nft-syn_flood"
/etc/init.d/nft-syn_flood enable
/etc/init.d/nft-syn_flood start

```

## Acknowledgements and Thanks

We would like to express our gratitude to the authors of OpenWRT SQM (Michael D. Taht, Toke Høiland-Jørgensen, and Sebastian Moeller), as well as the creators of OpenWRT firewall4, jeverley/dscpclassify, lynxthecat/cake-qos-simple, lynxthecat/cake-autorate, and Lochnair/tsping.

Special thanks to [jeverley](https://github.com/jeverley) for their original dscpclassify project which BakeSale is based on.

We also thank stintel for their support of the qoriq platform.
