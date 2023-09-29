#!/bin/bash

echo "============================================================================================================"
echo "Day MMM dd hh:mm:ss Year|Host                          |Address                                 |Flags     |"

# Generate DNS cache, extract lines containing 4F or CF, process them with awk, then sort
kill -SIGUSR1 $(pidof dnsmasq) && logread | grep -E '4F|CF|Host' | tac | awk '/Host/ { exit; }
    substr($0, 126, 1) != "D" && substr($0, 129, 1) != "H" && index(substr($0, 81, 40), ".") > 0 {
        print substr($0, 1, 24) "|" substr($0, 50, 30) "|" substr($0, 81, 40) "|" substr($0, 122, 10) "|"; }
' | sort -t '|' -r -k4,4 -k2,2
echo "============================================================================================================"
