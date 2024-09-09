#!/bin/bash
echo -e "\n---\nnetstat result"
netstat -gn

echo -e "\n---\n/proc/net/igmp"
cat /proc/net/igmp

echo -e "\n---\n/proc/net/ip_mr_vif"
cat /proc/net/ip_mr_vif

echo -e "\n---\n/proc/net/ip_mr_cache"
cat /proc/net/ip_mr_cache
