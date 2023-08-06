# Enhancing Nftables Utilization

This guide examines a script used to manage network traffic through nftables. The script incorporates the following key steps:

1. It generates dynamic entries for thread clients and services in sets with respective timeouts. These sets primarily monitor connections.

2. The script creates three specific maps (ct_dscp, ct_wmm, and dscp_ct) to match certain marks to chains for modifying Differentiated Services Code Point (DSCP) or Connection Tracking (ct) marks. These mappings assist in prioritizing and managing diverse network traffic.

3. Chains are designed to assign actions for different network traffic categories, often altering the DSCP or CT mark.

4. Two chains, 'input' and 'postrouting', are created to handle ingress and egress traffic specifically.

5. Within the input and postrouting chains, a decision tree is implemented that operates based on the value of the ct mark. Traffic without a ct mark is directed to static classification, where traffic is categorized based on predefined rules in the static_classify chain. Traffic with a ct mark of 0x80 is directed towards dynamic classification.

6. The static_classify chain contains rules that classify traffic according to the Layer 4 protocol and destination ports or addresses. For example, DNS traffic and DoH are classified as CS5 for prioritization. Additional traffic types such as SSH, BOOTP/DHCP, Microsoft Teams voice/video/sharing, Discord VoIP, Apple FaceTime, etc., are classified with specific marks.

7. The ct_set_* chains incorporate a bitwise operation (ct mark & 0xffffff40 | 0x00000040) to modify the ct mark, allowing the retention of additional bits in the ct mark.

Although the script is robust, enhancing it by classifying similar groups into sets or arrays could improve organization and readability. For example, the configuration `ip daddr { 13.107.64.0/18, 52.112.0.0/14, 52.122.0.0/15 }` could be grouped into a set and used in the rule instead of listing each address separately. This would involve the user creating an nftset in the /etc/config/dscpclqassify file, then composing an nft line of code. The created set could then be referenced in the rule.

## Suggestions for nftables Usage

The provided `nft` scripts are part of a network packet classification system. They appear to be configured to work with the `nftables` framework, a Linux kernel subsystem for packet filtering/networking.

The `main.nft` script sets up the primary structure for packet classification rules, including chains for input, postrouting, and other packet classifications. It also includes classification values based on various QoS (Quality of Service) protocols like DSCP (Differentiated Services Code Point) and WMM (Wi-Fi Multimedia).

The `maps.nft` script contains a series of maps that relate DSCP classes to conntrack marks and vice versa. These maps provide the ruleset that governs how packets are classified and marked.

The `verdict.nft` script contains a series of chains that apply a specific DSCP classification to a packet and another series of chains that apply a specific conntrack mark to a packet.

In terms of optimization, your scripts already appear quite efficient as they adhere to standard conventions for packet classification with nftables. These include:

1. Using variables and maps for clarity and ease of modification.
2. Grouping related actions into chains for easier rule set management.
3. Using the connection tracking system in nftables for efficient processing of packets related to the same connection.

However, here are a few additional suggestions:

1. **Avoid redundancy**: Ensure you're not duplicating any classification rules across your chains. Duplicate rules can lead to confusion and unnecessary processing overhead.

2. **Maintain clear comments**: Your scripts are well-commented; maintaining this practice will make your scripts easier to understand and maintain.

3. **Optimize for your specific use case**: The best configuration for your scripts will heavily depend on your specific network traffic. You might want to analyze your traffic to determine if there are any rarely used rules that could be removed, or common traffic patterns you could optimize.

4. **Sparingly use include statements**: In the `main.nft` script, you have include statements that pull in external scripts. If these external scripts are large or complex, they could slow down your script execution. Try to minimize the use of include statements, or ensure the scripts being included are as efficient as possible.

Please note, without understanding the full context and the kind of network traffic you are dealing with, it's challenging to provide a detailed optimization strategy. Always test changes in a controlled environment before deploying them in a production network.

## Simple setup for saving the DSCP mark into the connection tracking (ct) mark

The Linux kernel's nf_tables subsystem is a powerful mechanism for handling network packets. It offers numerous enhancements over the older iptables system. Here's a simple setup for saving the DSCP mark into the connection tracking (ct) mark:

```bash
#!/bin/sh

# Clear existing rules
nft flush ruleset

# Add a table in the 'ip' family
nft add table ip mytable

# Add chains to the table
nft add chain ip mytable prerouting { type filter hook prerouting priority -150 \; }
nft add chain ip mytable postrouting { type filter hook postrouting priority -150 \; }

# Store DSCP in ct mark in the prerouting chain
nft add rule ip mytable prerouting ct mark set ip dscp

# Restore DSCP from ct mark in the postrouting chain
nft add rule ip mytable postrouting ip dscp set ct mark
```

This setup includes a table called `mytable` in the `ip` family, and two chains `prerouting` and `postrouting` that hook into the relevant places in the networking stack.

The `prerouting` chain contains a rule that sets the ct mark to the packet's DSCP.

The `postrouting` chain has a rule that sets the packet's DSCP to the ct mark, restoring the original DSCP for packets leaving the system.

Remember to execute this script as a superuser.

This is a simple and straightforward method for storing the DSCP in the ct mark and restoring it. Depending on your use case, you may need to add more rules or chains to handle different types of packets or different networking scenarios.

Also, note that both the DSCP and ct mark are small integer values, so large DSCP values may cause collisions or overflows. You may need to consider this when designing your ruleset.

## reducing number of chains and replacing the ct_dscp and ct_wmm maps with bitwise shifting

Sure, I can provide some insights on how to simplify the number of chains by moving some of the rules into one chain. This will result in a reduction in the number of chains but it will not alter the logic of the configuration file. However, please note that it might affect readability, as having separate chains for different classification tasks can make the rules easier to understand and manage.

Here's how you can reduce the number of chains by merging all `dscp_set_XX` and `ct_set_XX` chains into two single chains respectively:

```nft
chain dscp_set {
    meta l4proto { tcp, udp } ip dscp set ct mark & 0x0000003f
}

chain ct_set {
    meta l4proto { tcp, udp } ct mark set ct mark & 0xffffff00 | (ip dscp << 2)
}
```

In the above, `XX` represents the DSCP mark being set. The key is using bitwise shifting and masking to select the relevant bits. In the `dscp_set` chain, we're shifting the conntrack mark right by 2 bits and setting it as the DSCP mark. In the `ct_set` chain, we're shifting the DSCP mark left by 2 bits and setting it as the conntrack mark.

Then, in the `postrouting` chain, you can replace the `vmap @ct_dscp` with a `jump dscp_set`:

```nft
chain postrouting {
    type filter hook postrouting priority mangle + 2; policy accept;
    oifname "lo" return
    ct mark & 0x000000ff == 0x00000000 ct direction original jump static_classify
    ct mark & 0x00000080 == 0x00000080 jump dynamic_classify
    oifname { "br-lan", "br-swlan", "eth2" } ct mark & 0x0000003f jump dscp_set
    ct mark & 0x0000003f jump dscp_set
}
```

Similarly, in the `static_classify` chain, you can replace the `goto ct_set_XX` with `jump ct_set`:

```nft
chain static_classify {
    meta l4proto { tcp, udp } th dport { 53, 853, 5353 } counter packets 0 bytes 0 jump ct_set comment "DNS"
    #...rest of rules...
}
```

Please note that it's essential to verify these changes in a test environment before deploying to production as they might affect network traffic classification and prioritization. You should also take note of the maintainability and readability of the configuration.
