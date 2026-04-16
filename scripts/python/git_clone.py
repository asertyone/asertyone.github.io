#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tty
import termios
import subprocess
import re

# ================= 配置資訊 =================
USER = "SD47606"
TOKEN = "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"
DOMAIN = "github.psa-cloud.com"
AUTH = f"{USER}:{TOKEN}@{DOMAIN}"

REPO_MAP = [
    ("cm", "spx03/stla.rtcu.connection-manager"),
    ("mc", "spx03/stla.rtcu.meta-services"),
    ("bp", "spx03/stla.rtcu.build-plan"),
    ("28mani", "spx28/manifest"),
    ("28maniw", "spx28/manifest.wiki"),
    ("28msc", "spx28/stla.rtcu.meta-stla-common"),
    ("28mcmj", "spx28/jn.rtcu.sa525m-meta-layers-meta-customizations-meta-jn"),
    ("28ajet", "spx28/jn.rtcu.src-app-jn-ethernet-test"),
    ("28jer", "spx28/jn.rtcu.src-system-jn-extra-rootfs"),
    ("28jcs", "spx28/jn.rtcu.src-service-jn-config-service"),
    ("28mj", "spx28/jn.rtcu.meta-joynext"),
]

# ANSI 顏色與控制碼
CLR_RESET    = "\033[0m"
CLR_BOLD     = "\033[1m"
CLR_CYAN     = "\033[36m"
CLR_GREEN    = "\033[32m"
CLR_RED      = "\033[31m"
CLR_YELLOW   = "\033[33m"
CLR_BLUE_BG  = "\033[44m\033[37m"
HIDE_CURSOR  = "\033[?25l"
SHOW_CURSOR  = "\033[?25h"
CLEAR_SCREEN = "\033[H\033[2J"

# ================= 工具函式 =================

def visual_len(s):
    """計算視覺寬度，忽略 ANSI 顏色代碼並處理全形字元"""
    ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
    plain_text = ansi_escape.sub('', s)
    width = 0
    for char in plain_text:
        width += 2 if ord(char) > 127 else 1
    return width

def pad_space(s, target_width):
    """基於視覺寬度補足空格以確保對齊"""
    return s + " " * (target_width - visual_len(s))

def getch():
    """讀取單個按鍵，包含 ESC 序列"""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(sys.stdin.fileno())
        ch = sys.stdin.read(1)
        if ch == '\x1b':
            ch += sys.stdin.read(2)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

# ================= 互動選單邏輯 =================

def show_menu():
    selected_indices = set()
    current_idx = 0
    num_repos = len(REPO_MAP)

    sys.stdout.write(HIDE_CURSOR)
    try:
        while True:
            # 準備畫面內容
            output = [CLEAR_SCREEN]
            output.append(f"{CLR_BOLD}{CLR_CYAN}🚀 PSA STLA.RTCU Repo Manager{CLR_RESET}")
            output.append(f"方向鍵 [{CLR_BOLD}↑/↓{CLR_RESET}] 移動 | 選取 [{CLR_BOLD}Space{CLR_RESET}] | 執行 [{CLR_BOLD}Enter{CLR_RESET}] | 退出 [{CLR_BOLD}q/Esc{CLR_RESET}]")
            output.append("─" * 75)

            for i, (alias, path) in enumerate(REPO_MAP):
                is_selected = i in selected_indices
                is_current = i == current_idx
                
                # 勾選框樣式
                mark = "◉" if is_selected else "◯"
                colored_mark = f"{CLR_GREEN}{mark}{CLR_RESET}" if is_selected else mark
                
                # 內容對齊處理
                alias_txt = pad_space(alias, 12)
                path_txt  = pad_space(path, 45)

                if is_current:
                    # 當前指向行 (藍底白字)
                    line = f"{CLR_BLUE_BG} ❯ {colored_mark} {alias_txt} | {path_txt} {CLR_RESET}"
                else:
                    # 普通行
                    line = f"   {colored_mark} {alias_txt} | {path_txt}"
                
                output.append(line)

            output.append("─" * 75)
            output.append(f"已勾選: {CLR_BOLD}{len(selected_indices)}{CLR_RESET} 個項目")
            
            sys.stdout.write("\n".join(output) + "\n")
            sys.stdout.flush()

            # 按鍵監聽
            key = getch()
            if key == '\x1b[A':   # Up
                current_idx = (current_idx - 1) % num_repos
            elif key == '\x1b[B': # Down
                current_idx = (current_idx + 1) % num_repos
            elif key == ' ':      # Space
                if current_idx in selected_indices:
                    selected_indices.remove(current_idx)
                else:
                    selected_indices.add(current_idx)
            elif key == '\r':     # Enter
                if not selected_indices:
                    selected_indices.add(current_idx) # 若沒選則執行當前那一項
                return list(selected_indices)
            elif key in ('q', '\x1b', 'Q'): # Quit
                return None
    finally:
        sys.stdout.write(SHOW_CURSOR)

# ================= 核心執行邏輯 =================

def run_git_task(selected_names):
    """執行智慧型 Clone 或 Pull"""
    print(f"\n{CLR_BOLD}❇️  正在啟動任務處理流程...{CLR_RESET}")
    
    for alias in selected_names:
        match = next((item for item in REPO_MAP if item[0] == alias), None)
        if not match:
            continue
            
        path = match[1]
        repo_name = path.split('/')[-1] # 從路徑提取目錄名
        url = f"https://{AUTH}/{path}.git"
        
        print(f"\n─── {CLR_BOLD}[{alias}]{CLR_RESET} ──────────────────────────")
        
        # 檢查目錄是否存在
        if os.path.exists(repo_name):
            print(f"🚩 資料夾 {CLR_YELLOW}{repo_name}{CLR_RESET} 已存在。")
            print(f"🔄 執行 {CLR_CYAN}git pull{CLR_RESET} 更新代碼...")
            try:
                # -C 參數讓 git 直接在目標目錄執行
                subprocess.run(["git", "-C", repo_name, "pull"], check=True)
                print(f"✅ 更新完成。")
            except subprocess.CalledProcessError:
                print(f"{CLR_RED}❌ 更新失敗，請檢查手動衝突或網路狀態。{CLR_RESET}")
        else:
            print(f"🚚 執行 {CLR_GREEN}git clone{CLR_RESET} 下載儲存庫...")
            try:
                subprocess.run(["git", "clone", url], check=True)
                print(f"✅ 複製完成。")
            except subprocess.CalledProcessError:
                print(f"{CLR_RED}❌ 複製失敗，請檢查 Token 權限或 URL。{CLR_RESET}")

    print(f"\n{CLR_BOLD}✨ 當前批次任務已結束。{CLR_RESET}")

# ================= 主程式 =================

def main():
    # 支援指令列直接呼叫 (e.g., ./git_clone.py cm mc)
    if len(sys.argv) > 1:
        args = sys.argv[1:]
        if "all" in args:
            targets = [r[0] for r in REPO_MAP]
        else:
            targets = args
        run_git_task(targets)
        return

    # 進入互動式循環模式
    while True:
        selected_idxs = show_menu()
        
        # 退出判斷
        if selected_idxs is None:
            print(f"\n{CLR_BOLD}👋 程式結束，祝你開發順利！{CLR_RESET}\n")
            break
            
        # 轉換索引為別名
        target_names = [REPO_MAP[i][0] for i in selected_idxs]
        
        # 執行任務
        run_git_task(target_names)
        
        # 停留讓使用者確認結果
        print(f"\n{CLR_CYAN}按任意鍵回到選單...{CLR_RESET}")
        getch()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.stdout.write(SHOW_CURSOR + "\n\n⚠️  已由使用者強制中斷。\n")
