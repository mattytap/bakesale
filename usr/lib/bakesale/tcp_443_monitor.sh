#!/bin/sh

# This script lists the 'vpn_bypass_analysis' table from nft to improve its readability.
# It performs the following operations: 
# 1. Adds newlines after opening braces.
# 2. On lines between 'elements = {' and '}', it replaces non-end-of-line commas with a comma followed by a newline.
# 3. Converts specific spaces before 'c' to tabs.
# 4. Removes leading spaces, left-aligning the content.
nft list table inet vpn_bypass_analysis | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep -E 'set |counter ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//'
