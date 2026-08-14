# Sube gestaltpatcher al iPhone (ramdisk SSH) y corre sobre el plist.
param(
    [string]$Binary = ".\gestaltpatcher",
    [string]$GestaltRemote = "/mnt2/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist",
    [int]$Port = 2222
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Binary)) { throw "Falta binario: $Binary (descarga artifact de GitHub Actions)" }

$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$hk = "SHA256:lb9y8xaKPkXl5gUgA+WHH5TbDlRwWZ6Io7BBLbX+PuE="

& $pscp -batch -P $Port -l root -pw alpine -hostkey $hk `
    $Binary "root@127.0.0.1:/mnt2/tmp/gestaltpatcher"
& $plink -batch -ssh -P $Port -l root -pw alpine -hostkey $hk 127.0.0.1 `
    "chmod +x /mnt2/tmp/gestaltpatcher && cp -f '$GestaltRemote' /mnt2/tmp/gestalt_to_patch.plist && /mnt2/tmp/gestaltpatcher /mnt2/tmp/gestalt_to_patch.plist; echo EXIT=$?"

Write-Host "Revisa stdout arriba: gestalt_key_offset y PATCH @..."
Write-Host "Plist parcheado en /mnt2/tmp/gestalt_to_patch.plist (copiar manualmente al destino si OK)"
