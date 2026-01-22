# 1. 定義您的網路設定值
$VlanID = 162
$IPAddress = "192.168.162.116"
$PrefixLength = 24  # 對應子網路遮罩 255.255.255.0
$Gateway = "192.168.162.35"
$VlanKeyword = "RegVlanID" # Realtek 網卡驅動程式中最常見的 VLAN 屬性名稱

# 2. 自動尋找 Realtek 網卡名稱 (InterfaceAlias)
# 尋找 InterfaceDescription 中包含 "Realtek" 且名稱不含 "Wi-Fi" 的網卡
$NetAdapter = Get-NetAdapter | Where-Object { 
    ($_.InterfaceDescription -like '*Realtek*') -and 
    ($_.Name -notlike '*Wi-Fi*') 
}

# 3. 檢查是否找到網卡
if ($NetAdapter -eq $null) {
    Write-Error "錯誤：找不到符合 'Realtek' 描述的網卡。請檢查您的網卡是否正確連接或名稱是否包含 'Realtek'。"
    exit
}

# 4. 將網卡名稱存入變數
$AdapterName = $NetAdapter.Name

# 顯示找到的網卡名稱
Write-Host "已找到網卡名稱：" $AdapterName -ForegroundColor Green
Write-Host "將設定 VLAN ID：" $VlanID -ForegroundColor Cyan
Write-Host "將設定 IP 位址：" $IPAddress -ForegroundColor Cyan


Write-Host "開始設定 VLAN ID $VlanID..." -ForegroundColor Yellow

try {
    # 設置網卡的進階屬性 (VLAN ID)
    Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $VlanKeyword -RegistryValue $VlanID -ErrorAction Stop

    Write-Host "VLAN ID $VlanID 設定成功！" -ForegroundColor Green
}
catch {
    Write-Warning "設定 VLAN ID 失敗。此網卡驅動程式可能不支援 '$VlanKeyword' 屬性或需要不同的屬性名稱。"
    Write-Warning "請嘗試手動在網卡內容 -> 進階中尋找 VLAN 設定選項。"
}

Write-Host "開始設定 IP 位址 $IPAddress..." -ForegroundColor Yellow

# 1. 確保切換到靜態 IP 前先將網卡設定為自動取得 DNS (最佳實踐)
Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ResetServerAddresses -ErrorAction SilentlyContinue

# 2. 移除網卡上所有現有的 IPv4 靜態 IP (如果有)
# (使用 Remove-NetIPAddress 避免 New-NetIPAddress 產生「已存在」的錯誤)
Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq 'Manual'} | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# 3. 移除所有現有的預設閘道 (NetRoute)
# (這一步是為了解決 'DefaultGateway already exists' 的錯誤)
$CurrentRoutes = Get-NetRoute -InterfaceAlias $AdapterName -AddressFamily IPv4 | Where-Object { 
    $_.DestinationPrefix -eq '0.0.0.0/0' 
}
if ($CurrentRoutes -ne $null) {
    Remove-NetRoute -InputObject $CurrentRoutes -Confirm:$false -ErrorAction SilentlyContinue
}

# 4. **設定 IP Address 和 Subnet Mask (PrefixLength)**
New-NetIPAddress -InterfaceAlias $AdapterName -IPAddress $IPAddress -PrefixLength $PrefixLength -ErrorAction Stop

# 5. **設定預設閘道 (Default Gateway)**
New-NetRoute -InterfaceAlias $AdapterName -DestinationPrefix "0.0.0.0/0" -NextHop $Gateway -ErrorAction Stop

Write-Host "IP 位址、子網路與閘道設定成功！" -ForegroundColor Green

# 驗證設定
Get-NetIPAddress -InterfaceAlias $AdapterName
Get-NetRoute -InterfaceAlias $AdapterName | Where-Object {$_.DestinationPrefix -eq '0.0.0.0/0'}
