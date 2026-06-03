#!/bin/bash

##############################################################################
# Root Privilege Check
##############################################################################
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script requires root privileges. Please run with sudo."
    exit 1
fi

##############################################################################
# Core Variables
##############################################################################
CORE_DROP_CHAINS="TCPIP_DROP_INV_PORT_TCP TCPIP_DROP_INV_PORT_UDP TCPIP_DROP_INV_IPV4_ADDR TCPIP_DROP_INV_IPV6_ADDR"

# Global temporary storage path for caching to maximize Yocto performance
TMP_SAVE="/tmp/fw_save.tmp"

##############################################################################
# Core Firewall Status Detection
##############################################################################
chain_has_drop() { iptables -S "$1" 2>/dev/null | grep -q -- "-j DROP"; }
policy_is_drop() { iptables -S INPUT 2>/dev/null | head -n 1 | grep -q "DROP"; }

##############################################################################
# Keyboard Event Listener (Strict Numeric Returns for Compatibility)
##############################################################################
get_key() {
    local key
    read -rsn1 key
    
    if [ "$key" = $'\x1b' ]; then
        read -rsn2 -t 0.1 key
        case "$key" in
            '[A') echo "1"; return ;; # UP
            '[B') echo "2"; return ;; # DOWN
            '[D') echo "3"; return ;; # LEFT
            '[C') echo "4"; return ;; # RIGHT
        esac
    fi

    if [ "$key" = "" ]; then
        echo "5" # ENTER
    elif [ "$key" = "v" ] || [ "$key" = "V" ]; then
        echo "6" # VIEW
    elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
        echo "7" # BYPASS
    elif [ "$key" = "t" ] || [ "$key" = "T" ]; then
        echo "8" # TOP
    elif [ "$key" = "m" ] || [ "$key" = "M" ]; then
        echo "9" # MOVE
    elif [ "$key" = "g" ] || [ "$key" = "G" ]; then
        echo "10" # GOTO
    elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
        echo "11" # QUIT
    else
        echo "0" # OTHER
    fi
}

##############################################################################
# Control Module A: Group A Operations
##############################################################################
toggle_all_drops() {
    local all_enabled=1
    for chain in $CORE_DROP_CHAINS; do
        if ! chain_has_drop "$chain"; then all_enabled=0; break; fi
    done
    if ! policy_is_drop; then all_enabled=0; fi

    echo ""
    if [ "$all_enabled" = "1" ]; then
        echo "[INFO] Disabling 4 Core Chains DROP and setting Default Policy to ACCEPT..."
        for chain in $CORE_DROP_CHAINS; do iptables -D "$chain" -j DROP 2>/dev/null; done
        iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
    else
        echo "[INFO] Enabling 4 Core Chains DROP and setting Default Policy to DROP..."
        for chain in $CORE_DROP_CHAINS; do
            if ! chain_has_drop "$chain"; then iptables -A "$chain" -j DROP 2>/dev/null; fi
        done
        iptables -P INPUT DROP; iptables -P OUTPUT DROP; iptables -P FORWARD DROP
    fi
    sleep 0.8
}

toggle_default_policy() {
    if policy_is_drop; then
        iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT
    else
        iptables -P INPUT DROP; iptables -P OUTPUT DROP; iptables -P FORWARD DROP
    fi
}

toggle_chain_drop() {
    if chain_has_drop "$1"; then
        iptables -D "$1" -j DROP 2>/dev/null
    else
        iptables -A "$1" -j DROP 2>/dev/null
    fi
}

##############################################################################
# Control Module B: Group B Core Actions
##############################################################################
toggle_jump_bypass_by_row() {
    local base_chain="$1" target_row="$2" target_chain="$3"
    if [ -z "$target_chain" ] || grep -qE 'ACCEPT|DROP|REJECT|LOG|RETURN' <<< "$target_chain"; then
        echo -e "\n[ERROR] Row $target_row ($target_chain) is not a valid custom jump target."
        sleep 1.2; return
    fi
    if grep -q "^-A $target_chain -j RETURN" "$TMP_SAVE" 2>/dev/null; then
        iptables -D "$target_chain" -j RETURN 2>/dev/null
    else
        iptables -I "$target_chain" 1 -j RETURN 2>/dev/null
    fi
}

move_to_top() {
    local base_chain="$1" from_row="$2"
    local original_rule=$(grep "^-A $base_chain " "$TMP_SAVE" | sed -n "${from_row}p")
    [ -z "$original_rule" ] && return
    local rule_cmd=$(echo "$original_rule" | sed "s/^-A $base_chain //")
    iptables -I "$base_chain" 1 $rule_cmd
    local corrected_from=$((from_row + 1))
    iptables -D "$base_chain" "$corrected_from"
}

move_rule_position() {
    local base_chain="$1" from_row="$2"
    echo ""
    printf "Move Row %s to Target Row Position: " "$from_row"
    read -r to_row
    if ! [[ "$to_row" =~ ^[0-9]+$ ]]; then echo "[ERROR] Target must be a valid number."; sleep 1.2; return; fi
    local original_rule=$(grep "^-A $base_chain " "$TMP_SAVE" | sed -n "${from_row}p")
    [ -z "$original_rule" ] && return
    local rule_cmd=$(echo "$original_rule" | sed "s/^-A $base_chain //")
    if [ "$from_row" -lt "$to_row" ]; then
        iptables -I "$base_chain" "$to_row" $rule_cmd
        iptables -D "$base_chain" "$from_row"
    else
        iptables -I "$base_chain" "$to_row" $rule_cmd
        local corrected_from=$((from_row + 1))
        iptables -D "$base_chain" "$corrected_from"
    fi
}

view_custom_chain_rules() {
    local target_chain="$1"
    clear
    echo "============================================================================================================="
    echo " [QUICK VIEW] Detailed Rules Inside Custom Chain: $target_chain"
    echo "============================================================================================================="
    echo ""
    
    if [ -f "$TMP_SAVE" ]; then
        local check_rules=$(grep "^-A $target_chain " "$TMP_SAVE")
        if [ -z "$check_rules" ]; then
            echo "   (No sub-rules defined inside this chain, default reference target only)"
        else
            grep "^-A $target_chain " "$TMP_SAVE" | sed 's/^-A /  -> /'
        fi
    else
        echo "   [ERROR] Cache storage unavailable. Unable to pull details."
    fi
    
    echo ""
    echo "============================================================================================================="
    echo " >> Press ANY KEY to close this preview window and return to pipeline flow..."
    get_key >/dev/null
}

##############################################################################
# Menu Rendering Engine
##############################################################################

# Sub-Menu 1: Group A Core Rules
menu_group_a() {
    local cursor=0
    while true; do
        clear
        echo "=========================================================================="
        echo "       [Group A: Core Rules & Policy Control] Status Overview"
        echo "=========================================================================="
        if policy_is_drop; then 
            echo -e " [*] Default Policy : \e[1;31mDROP\e[0m"
        else 
            echo -e " [ ] Default Policy : \e[1;32mACCEPT\e[0m"
        fi
        echo " ------------------------------------------------------------------------"
        for chain in $CORE_DROP_CHAINS; do
            if chain_has_drop "$chain"; then 
                printf " [*] %-35s : \e[1;31mENABLED\e[0m\n" "$chain"
            else 
                printf " [ ] %-35s : \e[1;32mDISABLED\e[0m\n" "$chain"
            fi
        done
        echo "=========================================================================="
        echo " Hotkeys: [↑/↓] Move, [→/ENTER] Toggle, [←] Back, [Q] Quit Entirely"
        echo "--------------------------------------------------------------------------"

        local options=(
            "Toggle ALL Drops (Link all 4 chains & Default Policy)"
            "Toggle Default Policy (Switch ACCEPT / DROP)"
            "Toggle TCP Invalid Port Drop Switch"
            "Toggle UDP Invalid Port Drop Switch"
            "Toggle Invalid IPv4 Drop Switch"
            "Toggle Invalid IPv6 Drop Switch"
            "<- Back to Upper Menu"
        )

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$cursor" ]; then
                echo -e " \e[1;36m> ${options[$i]}\e[0m"
            else
                echo "   ${options[$i]}"
            fi
        done

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge ${#options[@]} ] && cursor=0 ;;
            3)  break ;;
            11) rm -f "$TMP_SAVE"; exit 0 ;;
            4|5)
                case "$cursor" in
                    0) toggle_all_drops ;;
                    1) toggle_default_policy ;;
                    2) toggle_chain_drop TCPIP_DROP_INV_PORT_TCP ;;
                    3) toggle_chain_drop TCPIP_DROP_INV_PORT_UDP ;;
                    4) toggle_chain_drop TCPIP_DROP_INV_IPV4_ADDR ;;
                    5) toggle_chain_drop TCPIP_DROP_INV_IPV6_ADDR ;;
                    6) break ;;
                esac
                ;;
        esac
    done
}

# Sub-Menu 2-2: Actions on a selected Row
action_on_row_menu() {
    local base_chain="$1" target_row="$2" target_chain="$3"
    local cursor=0
    while true; do
        clear
        echo "=========================================================================="
        echo "  Operations for ${base_chain} -> [Row ${target_row}] Target Chain: ${target_chain}"
        echo "=========================================================================="
        echo " Hotkeys: [↑/↓] Move, [→/ENTER] Execute, [←] Back, [Q] Quit Entirely"
        echo "--------------------------------------------------------------------------"
        
        local options=(
            "Toggle Switch : Enable / Disable Bypass (RETURN) State"
            "Move to Top   : Force this rule to the highest priority (Row 1)"
            "Reorder Rule  : Freely move this rule to any row index position"
            "<- Cancel and Return"
        )
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$cursor" ]; then echo -e " \e[1;36m> ${options[$i]}\e[0m"; else echo "   ${options[$i]}"; fi
        done

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge ${#options[@]} ] && cursor=0 ;;
            3)  break ;;
            11) rm -f "$TMP_SAVE"; exit 0 ;;
            4|5)
                case "$cursor" in
                    0) toggle_jump_bypass_by_row "$base_chain" "$target_row" "$target_chain"; break ;;
                    1) move_to_top "$base_chain" "$target_row"; break ;;
                    2) move_rule_position "$base_chain" "$target_row"; break ;;
                    3) break ;;
                esac
                ;;
        esac
    done
}

# Sub-Menu 2: Pipeline view using Fully Integrated Hotkey Architecture
tune_specific_chain_flow_menu() {
    local base_chain="$1"
    local cursor=0
    local force_refresh=1

    local arr_rows=()
    local arr_targets=()
    local arr_cleans=()
    local arr_bypassed=()
    local arr_has_drop=()
    local count=0

    while true; do
        if [ "$force_refresh" -eq 1 ]; then
            rm -f "$TMP_SAVE"
            iptables -S > "$TMP_SAVE"

            arr_rows=() ; arr_targets=() ; arr_cleans=() ; arr_bypassed=() ; arr_has_drop=()
            count=0

            while read -r r_num c_line; do
                [ -z "$r_num" ] && continue
                
                local t_chain=$(grep "^-A $base_chain " "$TMP_SAVE" | sed -n "${r_num}p" | awk '{print $NF}')
                
                arr_rows[count]="$r_num"
                arr_targets[count]="$t_chain"
                arr_cleans[count]="$c_line"

                if grep -q "^-A $t_chain -j RETURN" "$TMP_SAVE" 2>/dev/null; then
                    arr_bypassed[count]=1
                else
                    arr_bypassed[count]=0
                fi

                if grep -q "^-A $t_chain -j DROP" "$TMP_SAVE" 2>/dev/null; then
                    arr_has_drop[count]=1
                else
                    arr_has_drop[count]=0
                fi

                ((count++))
            done < <(iptables -L "$base_chain" -n --line-numbers | grep -E 'SAM|ICMP|VLAN|LOCAL|NETNS|BRIDGE|TCPIP' | awk '{r=$1; $1=""; print r, $0}')
            
            force_refresh=0
        fi

        clear
        echo "============================================================================================================="
        echo "       [Group B] ${base_chain} Pipeline Flow ([↑/↓] Browse, [→/ENTER] Ops Menu, [Q] Quit Entirely)"
        echo "============================================================================================================="
        echo " Hotkeys: [B] Bypass, [T] Row 1, [M] Move Row, [G] Go to Row, [V] Peek Rules, [←] Back"
        echo "-------------------------------------------------------------------------------------------------------------"

        if [ "$count" -eq 0 ]; then
            echo " [INFO] No managed custom jump rules detected in ${base_chain} chain."
            echo "        Press any key to return..."
            get_key; break
        fi

        [ $cursor -ge "$count" ] && cursor=$((count - 1))
        [ $cursor -lt 0 ] && cursor=0

        local idx=0
        for ((idx=0; idx<count; idx++)); do
            local row_num="${arr_rows[idx]}"
            local clean_line="${arr_cleans[idx]}"
            
            local type_str=""
            local status_str=""
            local color_start=""
            local color_end="\e[0m"

            if [ "${arr_bypassed[idx]}" -eq 1 ]; then
                type_str="[Bypass]"
                status_str="-> (SKIPPED)"
                color_start="\e[1;33m"
            else
                type_str="[ACTIVE]"
                if [ "${arr_has_drop[idx]}" -eq 1 ]; then 
                    status_str="-> (DROP-ON)"
                    color_start="\e[1;31m"
                else 
                    status_str="-> (DROP-OFF)"
                    color_start="\e[1;32m"
                fi
            fi

            local part_prefix="   "
            [ "$idx" -eq "$cursor" ] && part_prefix=" \e[1;36m>\e[0m "
            
            local fmt_type=$(printf "%-8s" "$type_str")
            local fmt_row=$(printf "Row %-3s" "${row_num}:")
            local fmt_rule=$(printf "%-65s" "$clean_line")

            if [ "$idx" -eq "$cursor" ] ; then
                echo -e "${part_prefix}\e[1;36m${fmt_type} ${fmt_row} ${fmt_rule} ${status_str}\e[0m"
            else
                echo -e "${part_prefix}${color_start}${fmt_type}${color_end} ${fmt_row} ${fmt_rule} ${color_start}${status_str}${color_end}"
            fi
        done
        echo "============================================================================================================="

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((count - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge "$count" ] && cursor=0 ;;
            3)  break ;;
            11) rm -f "$TMP_SAVE"; exit 0 ;;
            7)
                toggle_jump_bypass_by_row "$base_chain" "${arr_rows[cursor]}" "${arr_targets[cursor]}"
                force_refresh=1
                ;;
            8)
                move_to_top "$base_chain" "${arr_rows[cursor]}"
                force_refresh=1
                ;;
            9)
                move_rule_position "$base_chain" "${arr_rows[cursor]}"
                force_refresh=1
                ;;
            10)
                echo ""
                printf "Go to Row Number: "
                read -r target_num
                if [[ "$target_num" =~ ^[0-9]+$ ]]; then
                    local found=0
                    for ((i=0; i<count; i++)); do
                        if [ "${arr_rows[i]}" -eq "$target_num" ]; then
                            cursor=$i
                            found=1
                            break
                        fi
                    done
                    if [ "$found" -eq 0 ]; then
                        echo "[ERROR] Row $target_num not found in the visible lists."
                        sleep 1
                    fi
                else
                    echo "[ERROR] Invalid row number format."
                    sleep 1
                fi
                ;;
            6)
                view_custom_chain_rules "${arr_targets[cursor]}"
                ;;
            4|5)
                action_on_row_menu "$base_chain" "${arr_rows[cursor]}" "${arr_targets[cursor]}"
                force_refresh=1
                ;;
        esac
    done
    rm -f "$TMP_SAVE"
}

# Sub-Menu 2-1: Base Chain Selector
menu_group_b() {
    local cursor=0
    while true; do
        clear
        echo "=========================================================================="
        echo "         [Group B: Pipeline Tuning & Live Debug] Select Main Chain"
        echo "=========================================================================="
        echo " Hotkeys: [↑/↓] Move Cursor, [→/ENTER] Enter Flow View, [←] Back, [Q] Quit"
        echo "--------------------------------------------------------------------------"
        local options=(
            "1. Tune INPUT Chain Flow (Most Common)"
            "2. Tune OUTPUT Chain Flow"
            "3. Tune FORWARD Chain Flow"
            "<- Back to Upper Menu"
        )
        
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$cursor" ]; then echo -e " \e[1;36m> ${options[$i]}\e[0m"; else echo "   ${options[$i]}"; fi
        done

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge ${#options[@]} ] && cursor=0 ;;
            3)  break ;;
            11) exit 0 ;;
            4|5)
                case "$cursor" in
                    0) tune_specific_chain_flow_menu "INPUT" ;;
                    1) tune_specific_chain_flow_menu "OUTPUT" ;;
                    2) tune_specific_chain_flow_menu "FORWARD" ;;
                    3) break ;;
                esac
                ;;
        esac
    done
}

# Sub-Menu 3: Group C Miscellaneous Tools
menu_group_c() {
    local cursor=0
    while true; do
        clear
        echo "=========================================================================="
        echo "                 [Group C: Miscellaneous System Tools]"
        echo "=========================================================================="
        echo " Hotkeys: [↑/↓] Move Cursor, [→/ENTER] Run Command, [←] Back, [Q] Quit"
        echo "--------------------------------------------------------------------------"
        local options=(
            "1. Show complete raw iptables rules with packet counters"
            "2. Reset all firewall counters to zero (iptables -Z)"
            "<- Back to Upper Menu"
        )
        
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$cursor" ]; then echo -e " \e[1;36m> ${options[$i]}\e[0m"; else echo "   ${options[$i]}"; fi
        done

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge ${#options[@]} ] && cursor=0 ;;
            3)  break ;;
            11) exit 0 ;;
            4|5)
                case "$cursor" in
                    0) 
                        echo ""
                        iptables -L INPUT -n -v --line-numbers
                        echo ""
                        echo "Press any key to return..."
                        get_key
                        ;;
                    1)
                        iptables -Z
                        echo "[OK] Firewall packet counters reset to zero."
                        sleep 0.8
                        ;;
                    2) break ;;
                esac
                ;;
        esac
    done
}

##############################################################################
# Main Entrance Menu (Level 1 Root Menu)
##############################################################################
main_menu() {
    local cursor=0
    while true; do
        clear
        echo "=========================================================================="
        echo "                 Firewall Interactive Debug Toolkit"
        echo "=========================================================================="
        echo " Guide: Use Arrow Keys [↑/↓] to Navigate, Press [→], [ENTER] or [Q] to Exit"
        echo "--------------------------------------------------------------------------"
        
        local options=(
            "1. Enter [Group A: Core Rules & Policy Control]"
            "2. Enter [Group B: Pipeline Tuning & Live Debug] (INPUT/OUTPUT/FORWARD)"
            "3. Enter [Group C: Miscellaneous System Tools]"
            "0. Exit Toolkit"
        )

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$cursor" ]; then
                echo -e " \e[1;36m> ${options[$i]}\e[0m"
            else
                echo "   ${options[$i]}"
            fi
        done
        echo "=========================================================================="

        case $(get_key) in
            1)  ((cursor--)); [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1)) ;;
            2)  ((cursor++)); [ $cursor -ge ${#options[@]} ] && cursor=0 ;;
            11) exit 0 ;;
            4|5)
                case "$cursor" in
                    0) menu_group_a ;;
                    1) menu_group_b ;;
                    2) menu_group_c ;;
                    3) exit 0 ;;
                esac
                ;;
        esac
    done
}

# Start Toolkit Execution
main_menu