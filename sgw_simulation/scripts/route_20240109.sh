#!/bin/bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.vlan2.proxy_arp=1
sudo sysctl -w net.ipv4.conf.vlan4.proxy_arp=1

#case 1 : 192.168.2.36
#sudo ip ru a iif vlan2 lookup 202
#sudo ip ru a iif vlan4 lookup 204
#sudo ip ro a default via 192.168.4.35 t 202
#sudo ip ro a default via 192.168.2.36 t 204

sudo ip ru a to 192.168.2.0/24 lookup 202
sudo ip ru a to 192.168.3.0/24 lookup 203
sudo ip ru a to 192.168.6.0/24 lookup 206
sudo ip ro a default dev vlan2 t 202
sudo ip ro a default dev vlan3 t 203
sudo ip ro a default dev vlan6 t 206

sudo ip ro a default dev vlan4 via 192.168.4.35

#case 2 : 192.168.162.37-41
sudo ip ru a to 192.168.162.37 lookup 262
sudo ip ru a to 192.168.162.38 lookup 262
sudo ip ru a to 192.168.162.39 lookup 262
sudo ip ru a to 192.168.162.40 lookup 262
sudo ip ru a to 192.168.162.41 lookup 262
sudo ip ro a default dev vlan2 t 262

sudo ip ru a from 192.168.162.37 lookup 362
sudo ip ru a from 192.168.162.38 lookup 362
sudo ip ru a from 192.168.162.39 lookup 362
sudo ip ru a from 192.168.162.40 lookup 362
sudo ip ru a from 192.168.162.41 lookup 362
sudo ip ro a default via 192.168.162.35 dev vlan4 t 362




