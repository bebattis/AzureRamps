# Turn on Based IIS Server
Add-WindowsFeature Web-Server
Set-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value "Test webapp running on host $($env:computername) !"

# Enable Service Map from Host
Invoke-WebRequest "https://aka.ms/dependencyagentwindows" -OutFile InstallDependencyAgent-Windows.exe
.\InstallDependencyAgent-Windows.exe /S