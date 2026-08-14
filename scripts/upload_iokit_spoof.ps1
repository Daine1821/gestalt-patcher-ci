# Upload libiokit_spoof.dylib to ramdisk — NO plist patch, NO reboot
param(
    [string]$Dylib = ".\libiokit_spoof.dylib",
    [string]$Remote = "/mnt2/tmp/libiokit_spoof.dylib",
    [int]$Port = 2222
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Dylib)) {
    throw "Falta dylib: $Dylib (descarga artifact libiokit_spoof-* de GitHub Actions)"
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
Write-Host "OK — dylib en ramdisk. NO se parcheo mobileactivationd plist."
Write-Host "Prueba manual (puede fallar AMFI):"
Write-Host "  export DYLD_INSERT_LIBRARIES=$Remote"
Write-Host "  export DYLD_FORCE_FLAT_NAMESPACE=1"
