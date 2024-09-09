#!/bin/bash

dev='enx00e04c6875f7'

echo "Create vlan4 interface .."
ip link add link enp2s0 name vlan4 type vlan id 4
ip addr add 192.168.4.112/24 brd 192.168.4.255 dev vlan4
ip addr add 192.168.162.112/24 brd 192.168.162.255 dev vlan4
ip link set dev vlan4 up

ip address del 192.168.225.46/24 dev enp2s0

echo "Create vlan2 interface .."
ip link add link $dev name vlan2 type vlan id 2
ip addr add 192.168.2.112/24 brd 192.168.2.255 dev vlan2
ip addr add 192.168.162.112/24 brd 192.168.162.255 dev vlan2
ip link set dev vlan2 up

echo "Create vlan3 interface .."
ip link add link $dev name vlan3 type vlan id 3
ip addr add 192.168.3.112/24 brd 192.168.3.255 dev vlan3
ip link set dev vlan3 up

echo "Create vlan6 interface .."
ip link add link $dev  name vlan6 type vlan id 6
ip addr add 192.168.6.112/24 brd 192.168.6.255 dev vlan6
ip link set dev vlan6 up

