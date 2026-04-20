#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tty
import termios
import subprocess
import json

# ================= 配置資訊 =================
USER = "SD47606"
TOKEN = "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"
DOMAIN = "github.psa-cloud.com"
AUTH = f"{USER}:{TOKEN}@{DOMAIN}"

# 自動獲取腳本所在資料夾，確保 repos.json 在任何地方執行都找得到
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
JSON_FILE = os.path.join(BASE_DIR, "repos.json")

# 顏色配置
CLR_RESET  = "\033[0m"
CLR_BOLD   = "\033[1m"
CLR_CYAN   = "\033[36m"
CLR_GREEN  = "\033[32m"
CLR_YELLOW = "\033[33m"
CLR_BLUE_BG = "\033[44m"

# ================= 工具函式 =================

def load_repo_data():
    if not os.path.exists(JSON_FILE):
        return []
    try:
        with open(JSON_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # 格式: (顯示別名, 完整路徑, 組織)
            return [(r['name'].replace('stla.rtcu.', ''), 
                     f"{r['owner']['login']}/{r['name']}", 
                     r['owner']['login']) for r in data]
    except:
        return []

def getch():
    """強化版讀取：支援方向鍵、PageUp/Down (序列長度可達 4)"""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
        if ch == '\x1b':
            # 嘗試讀取接下來的字元 (如 [5~, [A)
            extra = sys.stdin.read(2)
            ch += extra
            if extra in ('[5', '[6'): # PageUp/Down 需要多讀一位 (~)
                ch += sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

# ================= 選單邏輯 =================

def show_menu(all_repos):
    PAGE_SIZE = 30
    current_idx = 0
    query = ""
    selected_paths = set()

    while True:
        # 1. 根據搜尋字串過濾結果
        filtered = [r for r in all_repos if query.lower() in r[1].lower()]
        num_total = len(filtered)
        if num_total > 0:
            current_idx = max(0, min(current_idx, num_total - 1))
        
        # 2. 計算分頁
        num_pages = (num_total - 1) // PAGE_SIZE + 1 if num_total > 0 else 1
        current_page = (current_idx // PAGE_SIZE) + 1

        # 3. 渲染畫面
        os.system('clear')
        print(f"{CLR_BOLD}{CLR_CYAN}🚀 PSA Repo Manager{CLR_RESET} | 總計: {num_total}")
        print(f"🔎 搜尋: {CLR_YELLOW}{query}{CLR_RESET}_")
        print(f"分頁: {current_page} / {num_pages} (PgUp/PgDn 跳頁)")
        print("-" * 85)

        start = (current_idx // PAGE_SIZE) * PAGE_SIZE
        display_list = filtered[start : start + PAGE_SIZE]

        for i, (name, path, org) in enumerate(display_list):
            real_idx = start + i
            is_curr = (real_idx == current_idx)
            is_sel = path in selected_paths
            
            mark = "[V]" if is_sel else "[ ]"
            pointer = ">" if is_curr else " "
            line = f"{pointer} {mark} [{org:^5}] {name[:30]:<30} | {path}"
            
            if is_curr:
                print(f"{CLR_BLUE_BG}{line}{CLR_RESET}")
            else:
                print(line)

        print("-" * 85)
        # 提示動態變更
        nav_hint = "[j/k/q/a/c]導航" if not query else "打字搜尋中"
        print(f"已選: {len(selected_paths)} | {nav_hint} | [Space]勾選 [Enter]執行")

        # 4. 按鍵監聽
        key = getch()
        
        # --- 第一層：系統級強效鍵 (不論是否在搜尋模式都生效) ---
        if key == '\x1b[A': # 方向鍵 上
            if num_total > 0: current_idx = (current_idx - 1) % num_total
        elif key == '\x1b[B': # 方向鍵 下
            if num_total > 0: current_idx = (current_idx + 1) % num_total
        elif key in ('\x1b[6~', ']', '\x1b[C'): # PgDn, ], 右
            if num_total > 0: current_idx = min(num_total - 1, current_idx + PAGE_SIZE)
        elif key in ('\x1b[5~', '[', '\x1b[D'): # PgUp, [, 左
            if num_total > 0: current_idx = max(0, current_idx - PAGE_SIZE)
        elif key == '\r': # Enter
            if not selected_paths and num_total > 0:
                selected_paths.add(filtered[current_idx][1])
            return list(selected_paths)
        elif key == ' ': # Space
            if num_total > 0:
                p = filtered[current_idx][1]
                if p in selected_paths: selected_paths.remove(p)
                else: selected_paths.add(p)
        elif key == '\x1b': # Esc 強制退出
            return None

        # --- 第二層：搜尋敏感快捷鍵 (只有 query 為空時生效) ---
        elif not query:
            k = key.lower()
            if k == 'j': # 下
                if num_total > 0: current_idx = (current_idx + 1) % num_total
            elif k == 'k': # 上
                if num_total > 0: current_idx = (current_idx - 1) % num_total
            elif k == 'q': # 退出
                return None
            elif k == 'a': # 全選 (僅限目前過濾出的結果)
                for r in filtered: selected_paths.add(r[1])
            elif k == 'c': # 清除所有勾選
                selected_paths.clear()
            elif k == 'g': # 回到最頂端
                current_idx = 0

        # --- 第三層：搜尋打字邏輯 ---
        if key in ('\x7f', '\x08'): # Backspace
            query = query[:-1]
            current_idx = 0
        elif len(key) == 1 and key.isprintable():
            # 只有當 key 不是被上方攔截的功能鍵時，才加入搜尋
            # 這裡簡單處理：只要進入到這層的單字元都視為搜尋輸入
            query += key
            current_idx = 0

# ================= 任務執行 =================

def run_git_task(paths):
    print(f"\n{CLR_BOLD}❇️  正在執行 Git 任務...{CLR_RESET}")
    for p in paths:
        repo_name = p.split('/')[-1]
        url = f"https://{AUTH}/{p}.git"
        print(f"\n─── [ {repo_name} ] ──────────────────────────────────────────")
        if os.path.exists(repo_name):
            print(f"🔄 執行 git pull...")
            subprocess.run(["git", "-C", repo_name, "pull"])
        else:
            print(f"🚚 執行 git clone...")
            subprocess.run(["git", "clone", url])

def main():
    data = load_repo_data()
    if not data:
        print(f"{CLR_RED}❌ 找不到 {JSON_FILE}{CLR_RESET}")
        print("請先執行 PowerShell 腳本產出 repos.json")
        return

    while True:
        res = show_menu(data)
        if res is None:
            print("\n已退出程式。")
            break
        
        run_git_task(res)
        print(f"\n{CLR_CYAN}任務完成！按任意鍵返回選單...{CLR_RESET}")
        getch()

if __name__ == "__main__":
    main()
