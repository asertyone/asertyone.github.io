import os
import datetime
from PIL import Image
from PIL.ExifTags import TAGS
from hachoir.metadata import extractMetadata
from hachoir.parser import createParser
import sys

# 確保輸出不亂碼 (Win11 終端機常用 UTF-8)
sys.stdout.reconfigure(encoding='utf-8')

def get_media_date(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    
    # 處理照片
    if ext in ('.jpg', '.jpeg', '.png', '.tiff'):
        try:
            with Image.open(filepath) as img:
                exif_data = img._getexif()
                if exif_data:
                    for tag, value in exif_data.items():
                        decoded = TAGS.get(tag, tag)
                        if decoded in ("DateTimeOriginal", "DateTime"):
                            # EXIF 格式通常是 "2024:10:10 11:14:54"
                            return datetime.datetime.strptime(value, "%Y:%m:%d %H:%M:%S"), "EXIF"
        except:
            pass

    # 處理影片
    elif ext in ('.mp4', '.mov', '.m4v', '.avi'):
        try:
            parser = createParser(filepath)
            if parser:
                with parser:
                    metadata = extractMetadata(parser)
                    if metadata and metadata.has('creation_date'):
                        return metadata.get('creation_date'), "Meta"
        except:
            pass

    # 若以上失敗，使用檔案系統修改時間
    mtime = os.path.getmtime(filepath)
    return datetime.datetime.fromtimestamp(mtime), "System"

def main():
    # 定義目標資料夾路徑 (相對於程式所在的 ./Camera)
    source_dir = os.path.join('.', 'Camera')

    if not os.path.exists(source_dir):
        print(f"❌ 找不到目錄：{os.path.abspath(source_dir)}")
        return

    # 取得檔案清單
    files = [f for f in os.listdir(source_dir) if os.path.isfile(os.path.join(source_dir, f))]
    total = len(files)
    
    print(f"📂 正在處理目錄: {os.path.abspath(source_dir)}")
    print(f"📊 總計檔案數: {total}\n" + "="*50)

    count_success = 0
    
    for i, filename in enumerate(files, 1):
        old_path = os.path.join(source_dir, filename)
        ext = os.path.splitext(filename)[1].lower()
        
        # 取得日期與來源
        dt, source = get_media_date(old_path)
        
        # 格式化新檔名
        new_base = dt.strftime("%Y-%m-%d %H.%M.%S")
        new_name = f"{new_base}{ext}"
        new_path = os.path.join(source_dir, new_name)

        # 處理檔名重複問題
        if old_path != new_path:
            counter = 1
            while os.path.exists(new_path):
                new_name = f"{new_base}_{counter}{ext}"
                new_path = os.path.join(source_dir, new_name)
                counter += 1
            
            try:
                os.rename(old_path, new_path)
                print(f"[{i}/{total}] ✅ {source}: {filename} -> {new_name}")
                count_success += 1
            except Exception as e:
                print(f"[{i}/{total}] ❌ 錯誤: {filename} 無法改名 ({e})")
        else:
            print(f"[{i}/{total}] ⏩ 跳過: {filename} (格式已正確)")

    print("="*50 + f"\n🎉 任務完成！成功改名 {count_success} 個檔案。")

if __name__ == "__main__":
    main()