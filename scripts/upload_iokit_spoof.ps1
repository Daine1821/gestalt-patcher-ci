# Upload libiokit_spoof.dylib to device - NO plist patch, NO reboot
param(
    [string]$Dylib = ".\libiokit_spoof.dylib",
    [string]$Remote = "/mnt2/tmp/libiokit_spoof.dylib",
    [int]$Port = 2222
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Dylib)) {
    throw "Missing dylib: $Dylib (download libiokit_spoof-*-arm64e from GitHub Actions)"
}

$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$hk = "SHA256:lb9y8xaKPkXl5gUgA+WHH5TbDlRwWZ6Io7BBLbX+PuE="

Write-Host "[upload] $Dylib -> root@127.0.0.1:$Remote"
& $pscp -batch -P $Port -l root -pw alpine -hostkey $hk `
    $Dylib "root@127.0.0.1:$Remote"
& $plink -batch -ssh -P $Port -l root -pw alpine -hostkey $hk 127.0.0.1 `
    "chmod 755 '$Remote' && ls -la '$Remote' && file '$Remote' 2>/dev/null || true"

Write-Host ""
Write-Host "OK - dylib on device. Launchd NOT patched."
Write-Host "To patch mobileactivationd plist for normal boot:"
Write-Host "  .\scripts\patch_mad_launchd.ps1 -Dylib `"$Dylib`""
