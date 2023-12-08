#!/bin/bash

HOSTNAME="${COLLECTD_HOSTNAME:-localhost}"
RRD_DATABASE="/var/rrd/m300-WatchGuard-M300/autorate-all/autorate.rrd"
INTERVAL="${COLLECTD_INTERVAL:-60}"
LOG_FILE="/var/log/cake-autorate.primary.log"

BUFFER_SIZE=7             # Buffer size for median calculation
buffer_count=0            # Variable to keep track of the number of lines in the buffer
current_second=0          # Variable to keep track of the current second
previous_last_timestamp=0 # Variable to track end of rrd data

# Initialize seven variables to store each line of data
line1=""
line2=""
line3=""
middle_line=""
line5=""
line6=""
line7=""

process_autorate() {
    local log_data data reflector counter line

    reflector=""
    log_data=$(grep DATA "$LOG_FILE" | grep -v _HEADER | awk -v timestamp="$previous_last_timestamp" -F'; ' '$3 > timestamp')
    counter=$(echo "$log_data" | tail -1 | cut -d'; ' -f11)
    counter=$((counter - 1))
    log_data=$(echo "$log_data" | tail -15 | awk -F'; ' -v counter=$counter '$11 == counter')
    previous_last_timestamp=$(echo "$log_data" | tail -1 | cut -d'; ' -f3)

    # Process the log file line by line
    echo "$log_data" | while IFS= read -r line; do
        reflector=$(echo "$line" | cut -d';' -f10 | sed 's/^.//')
        line=$(echo "$line" | awk -v OFS=':' -F'; ' '{
            $28=(substr($28,length($28)-2)=="_bb")?10:0
            $29=(substr($29,length($29)-2)=="_bb")?10:0
            print $11,$5,$6,$7,$8,$12,$13+$14-$15,$13,$14,$15,$16,$17,$18+$19-$20,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31
        }')

        echo "PUTVAL \"$HOSTNAME/autorate-$reflector/autorate\" interval=$INTERVAL N:$line"
        echo "PUTVAL \"$HOSTNAME/autorate-all/autorate\" interval=$INTERVAL N:$line"
    done
}

# while not orphaned
while [ $(awk '$1 ~ "^PPid:" {print $2;exit}' /proc/$$/status) -ne 1 ]; do
    process_autorate
    sleep "${INTERVAL%%.*}"
done
exit

SEQUENCE
DL_ACHIEVED_RATE_KBPS
UL_ACHIEVED_RATE_KBPS
DL_LOAD_PERCENT
UL_LOAD_PERCENT

DL_OWD_BASELINE
DL_OWD_US
DL_OWD_DELTA_EWMA_US
DL_OWD_DELTA_US
DL_ADJ_DELAY_THR
UL_OWD_BASELINE
UL_OWD_US
UL_OWD_DELTA_EWMA_US
UL_OWD_DELTA_US
UL_ADJ_DELAY_THR
DL_SUM_DELAYS
DL_AVG_OWD_DELTA_US
DL_ADJ_AVG_OWD_DELTA_THR_US
UL_SUM_DELAYS
UL_AVG_OWD_DELTA_US
UL_ADJ_AVG_OWD_DELTA_THR_US
DL_LOAD_CONDITION
UL_LOAD_CONDITION
CAKE_DL_RATE_KBPS
CAKE_UL_RATE_KBPS
