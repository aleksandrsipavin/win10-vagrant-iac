# Bootstrap.ps1
Set-ExecutionPolicy Bypass -Scope Process -Force

# Folders on D:
$vmRoot      = 'D:\VM-Drives'
$vagrantHome = 'D:\vagrant'
New-Item -ItemType Directory -Force $vmRoot | Out-Null
New-Item -ItemType Directory -Force $vagrantHome | Out-Null

# Disable Hyper-V if enabled (VirtualBox conflict)
try {
  $bcd = (bcdedit /enum | Out-String)
  if ($bcd -match 'hypervisorlaunchtype\s+Auto') {
    bcdedit /set hypervisorlaunchtype off | Out-Null
    Write-Output 'INFO: Hyper-V disabled. Reboot required after bootstrap.'
  }
} catch {}

# Install Chocolatey if missing
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Core tools
choco install -y git virtualbox vagrant

# Point VirtualBox and Vagrant to D:
$VBox = "$Env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
if (Test-Path $VBox) { & $VBox setproperty machinefolder "$vmRoot" | Out-Null }
setx VAGRANT_HOME "$vagrantHome" | Out-Null
$Env:VAGRANT_HOME = $vagrantHome

# ---- Create/ensure VirtualBox NAT Network ----
$netName = 'NatNetwork'
$cidr    = '172.31.254.0/24'
if (Test-Path $VBox) {
  $natList = & $VBox list natnetworks | Out-String
  if ($natList -notmatch "Name:\s+$netName") {
    & $VBox natnetwork add --netname $netName --network $cidr --dhcp on
  } else {
    & $VBox natnetwork modify --netname $netName --network $cidr --dhcp on
  }
  try { & $VBox natnetwork start --netname $netName } catch {}
  Write-Output "INFO: NAT Network '$netName' ready on $cidr (DHCP on)."
} else {
  Write-Warning "VBoxManage not found. Ensure VirtualBox is installed and re-run this section."
}

Write-Output 'BOOTSTRAP DONE.'
