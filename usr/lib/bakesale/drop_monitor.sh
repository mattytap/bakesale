#!/bin/sh

# This script lists the 'fw4 dropped packet sets' from nft to improve its readability.
# It performs the following operations: 
# 1. Adds newlines after opening braces.
# 2. On lines between 'elements = {' and '}', it replaces non-end-of-line commas with a comma followed by a newline.
# 3. Converts specific spaces before 'c' to tabs.
# 4. Removes leading spaces, left-aligning the content.
# plus other stuff!
echo ""

echo "dropped_packets"
echo "================================================================================"
nft list set inet fw4 dropped_packets | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep 'counter ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
#sort -t ' ' -k6,6nr | \
#head -n 15 | \
awk -F'[. \t]' '
{
    prefix = $1 "." $2 "." $3;
    lines[prefix] = lines[prefix] ? lines[prefix] "\n" $0 : $0;
    count[prefix]++;
}
END {
    isFirst = 1;
    for (prefix in lines) {
        if (count[prefix] > 1) {
            if (isFirst)
                isFirst = 0;
            else
                print "---------------------------------------------------------------------------------"; 
                print lines[prefix];
            }
        }
    }'

echo ""

echo "dropped_ports"
echo "================================================================================"
nft list set inet fw4 dropped_ports | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep 'counter ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
sort -t ' ' -k3,3nr | \
head -n 100

echo ""

echo "ratelimit_ips"
echo "================================================================================"
nft list set inet fw4 ratelimit_ips | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep 'expires ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
sort -t ' ' -k8,8r | \
head -n 100

echo ""

echo "ratelimit_ips_logs"
echo "================================================================================"
nft list set inet fw4 ratelimit_ips_logs | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep 'expires ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
sort -t ' ' -k8,8r | \
head -n 100

echo ""

echo "bad_ips"
echo "================================================================================"
nft list set inet fw4 bad_ips | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep 'counter ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
sort -t ' ' -k3,3nr | \
head -n 100

echo ""

echo "bad subnets"
echo "================================================================================"
nft list set inet fw4 bad_ips | \
sed 's/{/{\n/g' | \
sed '/elements = {/,/}/!b; s/,\([^$]\)/,\n\1/g' | \
sed 's/ c/\tc/' | \
grep -E 'set |counter ' | \
grep -v 'ip daddr' | \
sed 's/set /\nset /g' | \
sed 's/^\s\+//' | \
#sort -t ' ' -k3,3nr | \
#head -n 20 | \
awk -F'[. \t]' '
{
    prefix = $1 "." $2 "." $3;
    lines[prefix] = lines[prefix] ? lines[prefix] "\n" $0 : $0;
    count[prefix]++;
}
END {
    isFirst = 1;
    for (prefix in lines) {
        if (count[prefix] > 1) {
            if (isFirst)
                isFirst = 0;
            else
                print "---------------------------------------------------------------------------------"; 
            print lines[prefix];
        }
    }
}'

echo ""
