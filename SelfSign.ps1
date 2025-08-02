if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run with administrator privileges."
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetScripts = @(
  "$($ScriptDir)\PSAccountManager.ps1",
  "$($ScriptDir)\PSPasswdGenerator.ps1"
)

$Cert = New-SelfSignedCertificate `
  -Subject "CN=PowerShell Script by myself, OU=Self-signed RootCA" `
  -KeyAlgorithm RSA `
  -KeyLength 4096 `
  -Type CodeSigningCert `
  -CertStoreLocation Cert:\CurrentUser\My\ `
  -NotAfter ([datetime]"2099/01/01")
Move-Item "Cert:\CurrentUser\My\$($Cert.Thumbprint)" Cert:\CurrentUser\Root

$RootCert = @(Get-ChildItem cert:\CurrentUser\Root -CodeSigningCert)[0]
$TargetScripts | ForEach-Object {
    Set-AuthenticodeSignature $_ $RootCert
}