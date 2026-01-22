import os
import shutil
import re
import sys

# 確保輸出不亂碼
sys.stdout.reconfigure(encoding='utf-8')

def organize_files_debug():
    source_dir = './Camera'
    target_root = '.' 
    
    # 1. 檢查目錄是否存在
    if not os.path.exists(source_dir):
        print(f"❌ 錯誤：找不到目錄 '{source_dir}'。請確認 Camera 資料夾在 D:\\workspace 下。")
        return

    # 2. 取得所有檔案
    all_items = os.listdir(source_dir)
    print(f"🔍 掃描中... 在 {source_dir} 內找到了 {len(all_items)} 個項目。")

    # 3. 過濾出檔案（排除資料夾）
    files = [f for f in all_items if os.path.isfile(os.path.join(source_dir, f))]
    
    if not files:
        print("❓ 警告：Camera 資料夾內『沒有檔案』（可能是空資料夾或全是子資料夾）。")
        return

    # 正則表達式：匹配 2024-10-10 這種格式
    date_pattern = re.compile(r'^(\d{4})-(\d{2})-(\d{2})')

    print(f"🚀 開始分析檔名...")
    print("=" * 60)

    move_count = 0
    match_fail_count = 0

    for filename in files:
        match = date_pattern.match(filename)
        if match:
            year, month, day = match.groups()
            folder_name = f"{year}.{month}.{day}"
            target_dir = os.path.join(target_root, folder_name)

            if not os.path.exists(target_dir):
                os.makedirs(target_dir)

            source_path = os.path.join(source_dir, filename)
            target_path = os.path.join(target_dir, filename)
            
            try:
                shutil.move(source_path, target_path)
                print(f"✅ 已搬移: {filename} -> {folder_name}/")
                move_count += 1
            except Exception as e:
                print(f"❌ 搬移失敗: {filename} ({e})")
        else:
            # 檔名不符合時，印出前幾個作為參考
            if match_fail_count < 5:
                print(f"⏩ 格式不符(範例): {filename}")
            match_fail_count += 1

    print("=" * 60)
    print(f"📊 統計結果：")
    print(f" - 成功搬移: {move_count}")
    print(f" - 格式不符跳過: {match_fail_count}")

if __name__ == "__main__":
    organize_files_debug()