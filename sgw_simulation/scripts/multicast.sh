#!/bin/bash
echo "==== Kernel Configurations ===="
#zgrep MULTICAST /boot/config-6.2.0-39-generic
#zgrep MROUTE /boot/config-6.2.0-39-generic
echo "==== sysctl  ===="
sysctl -w net.ipv4.conf.virtual2.rp_filter=0
sysctl -w net.ipv4.conf.virtual4.rp_filter=0
sudo iptables -t mangle -A PREROUTING -d 239.192.2.251 -j TTL --ttl-set 2
#sysctl -w net.ipv4.conf.virtual2.force_igmp_version=1
#sysctl -w net.ipv4.conf.virtual4.force_igmp_version=1

#echo "==== virtual2/rp_filter  ===="
#cat /proc/sys/net/ipv4/conf/virtual2/rp_filter
#echo "==== virtual4/rp_filter  ===="
#cat /proc/sys/net/ipv4/conf/virtual4/rp_filter
#echo "==== virtual2/ force_igmp_version ===="
#cat /proc/sys/net/ipv4/conf/virtual2/force_igmp_version
#echo "==== virtual4/ force_igmp_version ===="
#cat /proc/sys/net/ipv4/conf/virtual4/force_igmp_version

#echo "==== Run igmpproxy===="
#/usr/sbin/igmpproxy -d /etc/igmpproxy.conf

#echo "==== virtual2/mc_forwarding ===="
#cat /proc/sys/net/ipv4/conf/virtual2/mc_forwarding
#echo "==== virtual4/mc_forwarding ===="
#cat /proc/sys/net/ipv4/conf/virtual4/mc_forwarding
#echo "==== all/mc_forwarding ===="
#cat /proc/sys/net/ipv4/conf/all/mc_forwarding
#
#echo "==== /proc/net/ip_mr_cache ===="
#cat /proc/net/ip_mr_cache
#smcroute -d
#smcroute -a virutal4 192.168.4.35 224.0.0.17 virtual2
#smcroute -j virtual4 224.0.0.17
