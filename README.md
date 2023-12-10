# BakeSale

Bits and pieces related to OpenWrt deployments

## Installation

Assuming that SQM is already installed and running, you will then need to install the following and then configure /etc/config/sqm to use the new cake_ct script:

```bash
repo="https://raw.githubusercontent.com/mattytap/bakesale/mattytap"

# Download files using uclient-fetch
uclient-fetch -O "/usr/lib/bakesale" "$repo/usr/lib/bakesale/*"
uclient-fetch -O "/usr/libexec/collectd" "$repo/usr/libexec/collectd/*"
uclient-fetch -O "/etc/init.d" "$repo/etc/init.d/*"
uclient-fetch -O "/usr/share/collectd" "$repo/usr/share/collectd/*"
uclient-fetch -O "/usr/share/nftables.d/table-pre" "$repo/usr/share/nftables.d/table-pre/*"
uclient-fetch -O "/www/luci-static/resources/statistics" "$repo/www/luci-static/resources/statistics/*"
uclient-fetch -O "/www/luci-static/resources/statistics/rrdtool/definitions" "$repo/www/luci-static/resources/statistics/rrdtool/definitions/*"

# Set execute permissions
chmod +x "/usr/lib/bakesale"/*
chmod +x "/usr/libexec/collectd"/*
chmod +x "/etc/init.d/nft-syn_flood"

# Enable and start the service
/etc/init.d/nft-syn_flood enable
/etc/init.d/nft-syn_flood start

```

## Acknowledgements and Thanks

We would like to express our gratitude to the authors of OpenWRT SQM (Michael D. Taht, Toke Høiland-Jørgensen, and Sebastian Moeller), as well as the creators of OpenWRT firewall4, jeverley/dscpclassify, lynxthecat/cake-qos-simple, lynxthecat/cake-autorate, and Lochnair/tsping.

Special thanks to [jeverley](https://github.com/jeverley) for their original dscpclassify project which BakeSale is based on.

We also thank stintel for their support of the qoriq platform.
