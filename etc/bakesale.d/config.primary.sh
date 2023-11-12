#!/bin/bash

# *** OUTPUT AND LOGGING OPTIONS ***

output_processing_stats=1 	# enable (1) or disable (0) output monitoring lines showing processing stats
output_load_stats=1       	# enable (1) or disable (0) output monitoring lines showing achieved loads
output_reflector_stats=0  	# enable (1) or disable (0) output monitoring lines showing reflector stats
output_summary_stats=0          # enable (1) or disable (0) output monitoring lines showing summary stats
output_cake_changes=0     	# enable (1) or disable (0) output monitoring lines showing cake bandwidth changes
debug=0 		  	# enable (1) or disable (0) out of debug lines

# This can generate a LOT of records so be careful:
log_DEBUG_messages_to_syslog=1	# enable (1) or disable (0) logging of all DEBUG records into the system log.

# *** STANDARD CONFIGURATION OPTIONS ***

### For multihomed setups, it is the responsibility of the user to ensure that the probes
### sent by this instance of autorate actually travel through these interfaces.
### See ping_extra_args and ping_prefix_string

dl_if=wg-pbr-ingress   # download interface
ul_if=eth5             # upload interface
#dl_if=wg-pbr-ingress   # download interface
#ul_if=eth0             # upload interface

# tsping - round robin pinging using ICMP type 13 (owds)
pinger_binary=tsping
reflectors=(
9.9.9.9
9.9.9.10
9.9.9.11
51.89.246.112
# 68.183.47.155
81.86.192.137
88.221.179.22
139.162.236.188
165.227.226.101
176.58.97.97
# 185.119.173.61
54.38.79.34
# 216.119.155.40
83.223.106.13
# 185.151.30.20
88.221.134.176
88.221.134.219
# 185.119.173.110
# 153.92.7.133
# 78.141.242.201
# 141.136.39.134
178.79.178.168
31.220.106.30
141.136.34.49
# 104.91.71.208
145.14.154.204
151.101.17.124
104.103.202.80
92.123.140.18
92.123.142.64
45.32.182.255
109.70.148.31
# 206.189.23.206
92.123.120.163
92.123.120.191
# 178.62.92.136
139.162.211.173
130.185.146.187
176.32.230.8
185.61.152.66
104.97.148.93
23.72.145.161
# 72.247.176.58
# 54.36.167.68
104.103.195.51
87.76.28.173
# 144.124.16.238
23.72.154.212
141.136.43.106
104.91.71.204
23.40.43.114
23.40.43.98
185.119.173.97
72.247.176.50
95.101.63.185
5.39.103.114
23.72.153.243
#104.97.149.174 178.62.57.244 51.75.175.17 31.220.106.205 104.103.227.226 176.74.20.21 104.103.157.220 212.48.73.178 194.11.155.237 188.166.138.240 35.178.229.2 151.101.18.133 162.13.178.183 185.41.8.193 104.111.69.64 51.89.201.88 185.151.30.178 82.163.78.57 176.58.101.225 104.103.227.116 185.24.96.48 31.220.106.199 185.181.197.173 109.203.126.209 178.62.70.74 104.103.200.164 23.72.163.154 104.103.198.10 34.105.196.47
)

no_pingers=8 # number of pingers to maintain


# Set either of the below to 0 to adjust one direction only
# or alternatively set both to 0 to simply use autorate to monitor a connection
adjust_dl_shaper_rate=1 # enable (1) or disable (0) actually changing the dl shaper rate
adjust_ul_shaper_rate=1 # enable (1) or disable (0) actually changing the ul shaper rate

min_dl_shaper_rate_kbps=500  # minimum bandwidth for download (Kbit/s)
base_dl_shaper_rate_kbps=2000 # steady state bandwidth for download (Kbit/s)
max_dl_shaper_rate_kbps=10000  # maximum bandwidth for download (Kbit/s)

min_ul_shaper_rate_kbps=1000  # minimum bandwidth for upload (Kbit/s)
base_ul_shaper_rate_kbps=6000 # steady state bandwidth for upload (KBit/s)
max_ul_shaper_rate_kbps=10000  # maximum bandwidth for upload (Kbit/s)

#min_dl_shaper_rate_kbps=35000  # minimum bandwidth for download (Kbit/s)
#base_dl_shaper_rate_kbps=125000 # steady state bandwidth for download (Kbit/s)
#max_dl_shaper_rate_kbps=190000  # maximum bandwidth for download (Kbit/s)

#min_ul_shaper_rate_kbps=7500  # minimum bandwidth for upload (Kbit/s)
#base_ul_shaper_rate_kbps=20000 # steady state bandwidth for upload (KBit/s)
#max_ul_shaper_rate_kbps=50000  # maximum bandwidth for upload (Kbit/s)

# *** OVERRIDES ***

### See defaults.sh for additional configuration options
### that can be set in this configuration file to override the defaults.
### Place any such overrides below this line.

#startup_wait_s=60 # number of seconds to wait on startup (e.g. to wait for things to settle on router reboot)
