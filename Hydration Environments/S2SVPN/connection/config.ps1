# Inputs
$azureVpnPip
$PSK
$localPrivateIP
$azureVnetCIDR


# Disable Adapter Bindings Except for Ipv4
$adapter = Get-NetAdapter
$bindings = Get-NetAdapterBinding -Name $adapter.Name
Foreach($binding in $bindings){
    if($binding.ComponentID -eq 'ms_tcpip'){continue}
    else{Set-NetAdapterBinding -Name $adapter.Name -ComponentID $binding.ComponentID -Enabled $false}
}

# Disable NetBIOS over TCP/IP
$adapter = (get-wmiobject -ComputerName localhost win32_networkadapterconfiguration | Where {$_.serviceName -match 'netvsc'})
$adapter.SetTcpipNetbios(2)

# Install RRAS Windows Feature
Install-WindowsFeature DirectAccess-VPN -IncludeManagementTools
Install-WindowsFeature Routing -IncludeManagementTools

# Configure RRAS
Install-RemoteAccess -ComputerName 'Localhost' -DAInstallType 'FullInstall' -ConnectToAddress $azureVpnPip -InternetInterface 'Ethernet'
Install-RemoteAccess -VpnType 'VpnS2S'
$metric = ":24"
$IPv4Subnet = $localPrivateIP + $metric
Add-VpnS2SInterface -Name 'Azure S2S' -Protocol 'IKEv2' -Destination $azureVpnPip -AuthenticationMethod 'PSKOnly' -SharedSecret $PSK -Persistent -IPv4Subnet $IPv4Subnet

# Set Azure Vnet Routes in Routing Table
Foreach($CIDR in $azureVnetCIDR){
    New-NetRoute -DestinationPrefix $CIDR -InterfaceAlias 'Azure S2S' -NextHop $azureVpnPip
}
