# BakeSale

Bits and pieces related to OpenWrt running on a powerful PowerPC router/switch

## Installation

Assuming that SQM is already installed and running, you will then need to install the following and then configure /etc/config/sqm to use the new cake_ct script:

```bash
repo="https://raw.githubusercontent.com/mattytap/bakesale/mattytap"

mkdir -p "/usr/lib/bakesale"
mkdir -p "/usr/libexec/collectd"

wget "$repo/usr/lib/bakesale/*" -P "/usr/lib/bakesale"
wget "$repo/usr/libexec/collectd/*" -P "/usr/libexec/collectd"
wget "$repo/etc/init.d/nft-syn_flood" -O "/etc/init.d"

wget "$repo/usr/share/collectd/*" -P "/usr/share/collectd"
wget "$repo/usr/share/nftables.d/table-pre/*" -P "/usr/share/nftables.d/table-pre"

wget "$repo/www/luci-static/resources/statistics/rdtool.js" -O "/www/luci-static/resources/statistics"
wget "$repo/www/luci-static/resources/statistics/rrdtool/definitions/*" -P "/www/luci-static/resources/statistics/rrdtool/definitions"

chmod +x "/usr/lib/bakesale"/*
chmod +x "/usr/libexec/collectd"/*
chmod +x "/etc/init.d/nft-syn_flood"

/etc/init.d/nft-syn_flood enable
/etc/init.d/nft-syn_flood start

```


## Acknowledgements and Thanks

We would like to express our gratitude to the authors of OpenWRT SQM (Michael D. Taht, Toke Høiland-Jørgensen, and Sebastian Moeller), as well as the creators of OpenWRT firewall4, jeverley/dscpclassify, lynxthecat/cake-qos-simple, lynxthecat/cake-autorate, and Lochnair/tsping.

Special thanks to [jeverley](https://github.com/jeverley) for their original dscpclassify project which BakeSale is based on.

We also thank stintel for their support of the qoriq platform.
