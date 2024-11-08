#!/bin/bash

DNSMASQ_DIR="/tmp/dnsmasq"
OUT_FILE="/tmp/diagnostic_details.log"

{
	# date
	echo -e "\n[date]"
	date "+%Y-%m-%d %H:%M:%S"
	
	# FORCE_WIFI_CONN
	echo -e "\n[ls -l /app_data/conn/FORCE_WIFI_CONN]"
	ls -l /app_data/conn/FORCE_WIFI_CONN
	
	#  WifiManagerSetting.json 
	echo -e "\n[ls -l /app_data/wifi/WifiManagerSetting.json]"
	ls -l /app_data/wifi/WifiManagerSetting.json
	
	echo -e "\n[cat /app_data/wifi/WifiManagerSetting.json]"
	cat /app_data/wifi/WifiManagerSetting.json
		
	# WifiConState
	echo -e "\n\n[ls -l /tmp/wifi/WifiConState]"
	ls -l /tmp/wifi/WifiConState
	
	echo -e "\n[cat /tmp/wifi/WifiConState]"
	cat /tmp/wifi/WifiConState
	
	echo -e "\n[ls -l /data/coredump/]"
	ls -l /data/coredump/
	
	# Wi-FI info
	echo -e "\n[iw wlan0 info]"
	iw wlan0 info
	
	# ifconfig
	echo -e "\n[ifconfig]"
	ifconfig 
	
    # dnsmasq
	echo -e "\n[ps ax |egrep dnsmasq?]"
	ps ax |egrep "dnsmasq?"
	
    if [ -d "$DNSMASQ_DIR" ]; then
        echo -e "\n[Listing files and permissions in $DNSMASQ_DIR]"
        
        # List all files with their permissions
        ls -l "$DNSMASQ_DIR"
        echo -e "\nFile Contents:\n"
        
        # Loop through each file in the directory
        for file in "$DNSMASQ_DIR"/*; do
            if [ -f "$file" ]; then
                echo -e "--- $file ---"
                cat "$file"
                echo -e "\n" 
            fi
        done
    else
        echo "Error: Directory $DNSMASQ_DIR does not exist."
        exit 1
    fi
	
	# routing
	echo -e "\n*Listing route rules\n"
	ip ru l
	
	echo -e "\n*Listing route tables\n"
	echo -e "\n--- 111 ---\n"
	ip r s t 111
	
	echo -e "\n--- main ---\n"
	ip r s

	# ping test
	gateway_ip=$(awk -F'"gateway":"' '{print $2}' /tmp/wifi/WifiConState | awk -F'"' '{print $1}')
	if [ -n "$gateway_ip" ]; then
		echo -e "\nGet WiFi gateway IP address ($gateway_ip) from /tmp/wifi/WifiConState"
		echo -e "\n[ping -c 3 $gateway_ip]"
		ping -c 3 "$gateway_ip"
	else
		echo "No gateway IP found in $WIFI_STATE_FILE. Skipping ping."
	fi
	
	echo -e "\n[ping -c 3 8.8.8.8]"
	ping -c 3 8.8.8.8
	
	echo -e "\n[ping -c 3 www.google.com]"
	ping -c 3 www.google.com
} | tee "$OUT_FILE"

