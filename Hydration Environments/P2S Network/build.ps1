# Local VM Setup and PowerShell prerequisites
$certPrefix = "AzureP2S"
$certStoreLocation = "Cert:\CurrentUser\My"
$tempPath = "C:\temp\" + $certPrefix + "RootCert.cer"

$rootSubject = "CN=" + $certPrefix + "RootCert"
$childSubject = "CN=" + $certPrefix + "ChildCert"

$resourceGroupName = 'p2snet'
$location = 'eastus2'



# Make Root Cert
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject $rootSubject -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation $certStoreLocation -KeyUsageProperty Sign -KeyUsage CertSign

# Make Child Cert
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject $childSubject -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation $certStoreLocation `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# Export Root Cert to File
Export-Certificate -Cert $cert -FilePath $tempPath

# Get the Base64 Encoded Data
$bytes = [System.IO.File]::ReadAllBytes($tempPath)
$b64 = [System.Convert]::ToBase64String($bytes)

# Remove Exported Cert
Remove-Item -Path $tempPath -Force

# Check and Build Resource Group
try {Get-AzureRmResourceGroup -Name $resourceGroupName}
catch {New-AzureRmResourceGroup -Name $resourceGroupName -Location $location}

#