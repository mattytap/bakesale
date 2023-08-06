# DSCPClassify.md

**nftables based service for applying DSCP classifications to connections, compatible with OpenWrt's firewall4 for dynamically setting DSCP packet marks (this only works in OpenWrt 22.03 and above).**

This service should be used in conjunction with the layer-cake SQM queue with ctinfo configured to restore DSCP on the device ingress. The service uses the last 8 bits of the conntrack mark (0x000000ff).

## Classification modes

The service supports three modes for classifying and DSCP marking connections:

### User rules

The service will first attempt to classify new connections using rules specified by the user in the config file. These rules follow a syntax similar to the OpenWrt firewall config and can match source/destination ports and IPs, firewall zones, etc. Nft sets can be used in the rules, which can be dynamically updated from external sources like dnsmasq.

### Client DSCP hinting

The service can be configured to apply the DSCP mark supplied by a non-WAN originating client. However, it ignores CS6 and CS7 classes to prevent abuse from inappropriately configured LAN clients, such as IoT devices.

### Dynamic classification

Connections that do not match a pre-specified rule will be dynamically classified by the service via two mechanisms:

* Multi-connection client port detection for detecting P2P traffic:
  * These connections are classified as Low Effort (LE) by default and are prioritized below Best Effort traffic when using the layer-cake qdisc.

* Multi-threaded service detection for identifying high-throughput downloads from services like Steam/Windows Update:
  * These connections are classified as High-Throughput (AF13) by default and are prioritized as follows by the cake qdisc:
    * diffserv3/4: Equal to besteffort (CS0) traffic.
    * diffserv8: Below besteffort (CS0) traffic, but above low effort (LE) traffic.

### External classification

The service will respect DSCP classification stored by an external service in a connection's conntrack bits. This could include services such as netifyd. For more information, see <https://www.man7.org/linux/man-pages/man8/tc-ctinfo.8.html>.

## Service architecture

![image](https://user-images.githubusercontent.com/46714706/188151111-9167e54d-482e-4584-b43b-0759e0ad7561.png)

## Service installation

To install the service via the command line, you can use the following:

```bash
repo="https://raw.githubusercontent.com/jeverley/dscpclassify/main"
mkdir -p "/etc/dscpclassify.d"
if [ ! -f "/etc/config/dscpclassify" ]; then
    wget "$repo/etc/config/dscpclassify" -O "/etc/config/dscpclassify"
else
    wget "$repo/etc/config/dscpclassify" -O "/etc/config/dscpclassify_git"
fi
wget "$repo/etc/dscpclassify.d/main.nft" -O "/etc/dscpclassify.d/main.nft"
wget "$repo/etc/dscpclassify.d/maps.nft" -O "/etc/dscpclassify.d/maps.nft"
wget "$repo/etc/dscpclassify.d/verdicts.nft" -O "/etc/dscpclassify.d/verdicts.nft"
wget "$repo/etc/hotplug.d/iface/21-dscpclassify" -O "/etc/hotplug.d/iface/21-dscpclassify"
wget "$repo/etc/init.d/dscpclassify" -O "/etc/init.d/dscpclassify"
chmod +x "/etc/init.d/dscpclassify"
/etc/init.d/dscpclassify enable
/etc/init.d/dscpclassify start
```

Note: The START value in the init.d and hotplug scripts is set to 21 to ensure they run after all network interfaces are up. The filenames `20-dscpclassify` and `dscpclassify` in the `/etc/init.d` and `/etc/hotplug.d/iface` directories, respectively, are important for correct execution order.

**SQM should be installed and configured on your device.**

The OpenWrt guide for configuring this is available here: <https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm>

Ingress DSCP marking requires the SQM queue setup script 'layer_cake_ct.qos' and the package 'kmod-sched-ctinfo'.

To install these via the command line, you can use the following:

```bash
repo="https://raw.githubusercontent.com/mattytap/dscpclassify/bakesale"
opkg update
opkg install kmod-sched-ctinfo
wget "$repo/usr/lib/sqm/layer_cake_ct.qos" -O "/usr/lib/sqm/layer_cake_ct.qos"
wget "$repo/usr/lib/sqm/layer_cake_ct.qos.help" -O "/usr/lib/sqm/layer_cake_ct.qos.help"
```

## Service configuration

The user rules in '/etc/config/dscpclassify' use the same syntax as OpenWrt's firewall config, and the 'class' option is used to specify the desired DSCP.

A working default configuration is provided with the service.

**The service supports the following global classification options:**

| Config option         | Description                                                                                  | Type    | Default |
|-----------------------|----------------------------------------------------------------------------------------------|---------|---------|
| class_bulk            | The class applied to threaded bulk clients                                                   | string  | le      |
| class_high_throughput | The class applied to threaded high-throughput services                                      | string  | af13    |
| client_hints          | Adopt the DSCP class supplied by a non-WAN client (this excludes CS6 and CS7 classes)      | boolean | 1       |
| threaded_client_min_bytes | The total bytes before a threaded client port (i.e., P2P) is classified as bulk            | uint    | 10000   |
| threaded_client_min_connections | The number of established connections for a client port to be considered               | uint    | 5       |
