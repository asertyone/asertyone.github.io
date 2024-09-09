#!/bin/bash
ip link add link enp2s0 name vlan4 type vlan id 4
ip addr add 192.168.4.112/24 brd 192.168.4.255 dev vlan4
ip addr add 192.168.162.112/24 brd 192.168.162.255 dev vlan4
ip link set dev vlan4 up

ip address del 192.168.225.46/24 dev enp2s0

ip link add link enx5c925ed6d463 name vlan2 type vlan id 2
ip addr add 192.168.2.112/24 brd 192.168.2.255 dev vlan2
ip addr add 192.168.162.112/24 brd 192.168.162.255 dev vlan2
ip link set dev vlan2 up

