#!/bin/bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.virtual2.proxy_arp=1
sudo sysctl -w net.ipv4.conf.virtual4.proxy_arp=1

#case 1 : 192.168.2.36
sudo ip ru a iif virtual2 lookup 202
sudo ip ru a iif virtual4 lookup 204
sudo ip ro a default via 192.168.4.35 t 202
sudo ip ro a default via 192.168.2.36 t 204

#case 2 : 192.168.162.37-41
sudo ip ru a from 192.168.162.37 lookup 262
sudo ip ru a from 192.168.162.38 lookup 262
sudo ip ru a from 192.168.162.39 lookup 262
sudo ip ru a from 192.168.162.40 lookup 262
sudo ip ru a from 192.168.162.41 lookup 262
sudo ip ro a default via 192.168.162.35 dev virtual4 t 262

sudo ip ru a to 192.168.162.37 lookup 263
sudo ip ru a to 192.168.162.38 lookup 263
sudo ip ru a to 192.168.162.39 lookup 263
sudo ip ru a to 192.168.162.40 lookup 263
sudo ip ru a to 192.168.162.41 lookup 263
sudo ip ro a default dev virtual2 t 263



