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
TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
DOMAIN = "github.psa-cloud.com"
AUTH = f"{USER}:{TOKEN}@{DOMAIN}"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
JSON_FILE = os.path.join(BASE_DIR, "repos.json")

# 顏色
CLR_RESET  = "\033[0m"
CLR_BOLD   = "\033[1m"
CLR_CYAN   = "\033[36m"
CLR_GREEN  = "\033[32m"
CLR_YELLOW = "\033[33m"
CLR_BLUE_BG = "\033[44m"
CLR_RED = "\033[31m"


# ================= 工具 =================
def load_repo_data():
    if not os.path.exists(JSON_FILE):
        return []
    try:
        with open(JSON_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return [
                (
                    r['name'].replace('stla.rtcu.', ''),
                    f"{r['owner']['login']}/{r['name']}",
                    r['owner']['login']
                )
                for r in data
            ]
    except:
        return []


def getch():
    """支援方向鍵 / PgUp / PgDn"""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
        if ch == '\x1b':
            extra = sys.stdin.read(2)
            ch += extra
            if extra in ('[5', '[6'):
                ch += sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch


# ================= UI =================
def show_menu(all_repos):
    PAGE_SIZE = 30
    current_idx = 0
    query = ""
    selected_paths = set()

    while True:
        filtered = [r for r in all_repos if query.lower() in r[1].lower()]
        num_total = len(filtered)

        if num_total > 0:
            current_idx = max(0, min(current_idx, num_total - 1))

        num_pages = (num_total - 1) // PAGE_SIZE + 1 if num_total > 0 else 1
        current_page = (current_idx // PAGE_SIZE) + 1

        os.system('clear')
        print(f"{CLR_BOLD}{CLR_CYAN}🚀 PSA Repo Manager{CLR_RESET} | 總計: {num_total}")
        print(f"🔎 搜尋: {CLR_YELLOW}{query}{CLR_RESET}_")
        print(f"分頁: {current_page} / {num_pages} (PgUp/PgDn)")
        print("-" * 85)

        start = (current_idx // PAGE_SIZE) * PAGE_SIZE
        display_list = filtered[start:start + PAGE_SIZE]

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
        nav_hint = "[j/k/q/a/c]導航" if not query else "搜尋中"
        print(f"已選: {len(selected_paths)} | {nav_hint} | [Space]勾選 [Enter]執行")

        key = getch()
        k = key.lower()

        # ================= 🔥 全域快捷鍵（永遠有效） =================
        if k == 'q':
            return None

        elif key == ' ':
            if num_total > 0:
                p = filtered[current_idx][1]
                if p in selected_paths:
                    selected_paths.remove(p)
                else:
                    selected_paths.add(p)

        elif key == '\r':
            if not selected_paths and num_total > 0:
                selected_paths.add(filtered[current_idx][1])
            return list(selected_paths)

        elif key == '\x1b':  # ESC
            if query:
                query = ""      # 清搜尋
                current_idx = 0
            else:
                return None     # 離開

        # ================= 方向鍵 =================
        elif key == '\x1b[A':
            if num_total > 0:
                current_idx = (current_idx - 1) % num_total

        elif key == '\x1b[B':
            if num_total > 0:
                current_idx = (current_idx + 1) % num_total

        elif key in ('\x1b[6~', ']'):
            if num_total > 0:
                current_idx = min(num_total - 1, current_idx + PAGE_SIZE)

        elif key in ('\x1b[5~', '['):
            if num_total > 0:
                current_idx = max(0, current_idx - PAGE_SIZE)

        # ================= 非搜尋模式快捷鍵 =================
        elif not query:
            if k == 'j':
                if num_total > 0:
                    current_idx = (current_idx + 1) % num_total

            elif k == 'k':
                if num_total > 0:
                    current_idx = (current_idx - 1) % num_total

            elif k == 'a':
                for r in filtered:
                    selected_paths.add(r[1])

            elif k == 'c':
                selected_paths.clear()

            elif k == 'g':
                current_idx = 0

        # ================= 搜尋輸入 =================
        if key in ('\x7f', '\x08'):  # Backspace
            query = query[:-1]
            current_idx = 0

        elif len(key) == 1 and key.isprintable() and key != ' ':
            query += key
            current_idx = 0


# ================= Git =================
def run_git_task(paths):
    print(f"\n{CLR_BOLD}❇️ 正在執行 Git 任務...{CLR_RESET}")

    for p in paths:
        repo_name = p.split('/')[-1]
        url = f"https://{AUTH}/{p}.git"

        print(f"\n─── [ {repo_name} ] ─────────────────────────")

        if os.path.exists(repo_name):
            print("🔄 git pull...")
            subprocess.run(["git", "-C", repo_name, "pull"])
        else:
            print("🚚 git clone...")
            subprocess.run(["git", "clone", url])


# ================= main =================
def main():
    data = load_repo_data()

    if not data:
        print(f"{CLR_RED}❌ 找不到 {JSON_FILE}{CLR_RESET}")
        return

    while True:
        res = show_menu(data)

        if res is None:
            print("\n已退出程式")
            break

        run_git_task(res)

        print(f"\n{CLR_CYAN}完成！按任意鍵返回選單...{CLR_RESET}")
        getch()


if __name__ == "__main__":
    main()
