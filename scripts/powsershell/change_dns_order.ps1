$interface = "乙太網路"
$localDNS = @("10.57.48.107","10.57.48.110")
$vpnDNS = @("151.171.137.254","151.171.73.254")
$dnsList = $localDNS + $vpnDNS
Set-DnsClientServerAddress -InterfaceAlias $interface -ServerAddresses $dnsList
Get-DnsClientServerAddress -InterfaceAlias $interface
