# Network Configuration Guidelines

## DSCP

Differentiated Services Code Point (DSCP) is a mechanism in networking used for classifying, managing network traffic, and providing a mechanism for Quality of Service (QoS). DSCP includes several commonly recognized markings:

- **Class Selector (CS)**: Designed for backward compatibility with IP Precedence.
- **Assured Forwarding (AF)**: A set of values that ensure reliable packet delivery.
- **Expedited Forwarding (EF)**: Devised for low loss, low latency traffic.

We also consider the following markings:

- **Lower Effort (LE)**: Prioritizes certain traffic less. While its usage was not widespread as of 2021, the adoption rate may have increased since then.
- **Default Forwarding (DF)**: The class used for traffic not fitting the criteria of any of the other defined classes. Traffic marked with a DSCP of DF (or 0) is treated as best-effort service at each node along its route, meaning it's forwarded if resources are available, but may be dropped during congestion. This is the standard behavior for Internet traffic.
- **Voice Admit (VA)**: Used for Voice over IP (VoIP) traffic control over a Diffserv domain. As of 2021, its usage is not common.

In our network's context, we prioritize the use of four DSCP values that best align with our service requirements:

| User Priority | Service Class | Typical DSCP Value |
| --- | --- | --- |
| 1 (Background) | BK | CS1 or DSCP 8 |
| 2 (Best Effort) | BE | Default or DSCP 0 |
| 5 (Video) | VI | AF41 or DSCP 34 |
| 6 (Voice) | VO | EF or DSCP 46 |

These settings depend on network device compatibility and the interpretation of DSCP markings. It's crucial to align your devices and policies for effective DSCP value implementation.

Remember, DSCP values can be altered or disregarded once traffic leaves the local network and interacts with Internet Service Providers or other network devices. Therefore, consult your specific device's documentation or contact the technical team for additional information or implementation assistance.

Also, keep in mind that these mappings can vary based on specific network requirements and the QoS policies in place. Consistency in how your network devices and policies interpret these markings is essential to achieve the expected behavior.