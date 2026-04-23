# 1. 定義要抓取的目標組織
$orgs = @("spx03", "spx05", "spx12", "spx28")
$allRepos = @()

# 2. 循環遍歷每個組織
foreach ($org in $orgs) {
    Write-Host "正在抓取組織 $org 的專案清單..." -ForegroundColor Cyan
    
    # 使用 gh repo list 抓取資料
    # --limit 1000 確保抓到所有專案
    # --json 指定輸出的欄位，這會與你 Python 腳本中使用的欄位對應
    $repos = gh repo list $org --limit 1000 --json name,owner,description | ConvertFrom-Json
    
    # 彙整到總清單
    $allRepos += $repos
}

# 3. 將彙整後的物件轉為 JSON 並存檔
# -Depth 10 確保巢狀結構（如 owner 欄位）被完整轉換
$allRepos | ConvertTo-Json -Depth 10 | Out-File -FilePath "repos.json" -Encoding utf8

Write-Host "`n✅ 完成！已產出 $($allRepos.Count) 個專案至 repos.json" -ForegroundColor Green