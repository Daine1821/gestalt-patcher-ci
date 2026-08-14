# Upload arm64e libiokit_spoof.dylib + patch mobileactivationd LaunchDaemon plist.
# Use AFTER normal boot (or ramdisk with mnt1 writable). Does NOT reboot.
param(
    [string]$Dylib = ".\libiokit_spoof.dylib",
    [string]$RemoteDylib = "/mnt2/tmp/libiokit_spoof.dylib",
    [int]$Port = 2222,
    [switch]$UploadOnly,
    [switch]$Restore
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PatchPy = Join-Path $ScriptDir "patch_mad_launchd.py"
$WorkDir = Join-Path $env:TEMP ("mad_launchd_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

$plink = "C:\Program Files\PuTTY\plink.exe"
$pscp = "C:\Program Files\PuTTY\pscp.exe"
$hk = "SHA256:lb9y8xaKPkXl5gUgA+WHH5TbDlRwWZ6Io7BBLbX+PuE="

$LaunchdCandidates = @(
    "/mnt1/System/Library/LaunchDaemons/com.apple.mobileactivationd.plist",
    "/System/Library/LaunchDaemons/com.apple.mobileactivationd.plist"
)
$BackupRemote = "/mnt2/tmp/com.apple.mobileactivationd.plist.bak"
$PatchedRemote = "/mnt2/tmp/com.apple.mobileactivationd.plist.patched"

function Invoke-Device([string]$Cmd) {
    & $plink -batch -ssh -P $Port -l root -pw alpine -hostkey $hk 127.0.0.1 $Cmd
    if ($LASTEXITCODE -ne 0) { throw "plink failed: $Cmd" }
}

function Find-LaunchdPlist {
    foreach ($p in $LaunchdCandidates) {
        $out = Invoke-Device "test -f '$p' && echo YES || echo NO"
        if ($out -match "YES") { return $p }
    }
    return $null
}

try {
    if (-not $Restore -and -not (Test-Path $Dylib)) {
        throw "Missing dylib: $Dylib (download libiokit_spoof-*-arm64e artifact from GitHub Actions)"
    }

    Write-Host "[ssh] 127.0.0.1:$Port ..."
    Invoke-Device "echo SSH_OK; uname -a" | Out-Host

    if (-not $Restore) {
        Write-Host "[upload] $Dylib -> $RemoteDylib"
        & $pscp -batch -P $Port -l root -pw alpine -hostkey $hk `
            $Dylib "root@127.0.0.1:$RemoteDylib"
        if ($LASTEXITCODE -ne 0) { throw "pscp dylib failed" }
        Invoke-Device "chmod 755 '$RemoteDylib' && file '$RemoteDylib' 2>/dev/null || true" | Out-Host
    }

    if ($UploadOnly) {
        Write-Host ""
        Write-Host "OK upload-only. Dylib at $RemoteDylib"
        Write-Host "To patch launchd: .\patch_mad_launchd.ps1 -Dylib `"$Dylib`" (without -UploadOnly)"
        return
    }

    $srcPlist = Find-LaunchdPlist
    if (-not $srcPlist) {
        throw "mobileactivationd.plist not found (need mnt1 or normal boot root)"
    }
    Write-Host "[launchd] source: $srcPlist"

    $localSrc = Join-Path $WorkDir "com.apple.mobileactivationd.plist"
    $localOut = Join-Path $WorkDir "com.apple.mobileactivationd.patched.plist"

    & $pscp -batch -P $Port -l root -pw alpine -hostkey $hk `
        "root@127.0.0.1:$srcPlist" $localSrc
    if ($LASTEXITCODE -ne 0) { throw "pscp download plist failed" }

    if ($Restore) {
        if (-not (Test-Path $PatchPy)) { throw "Missing $PatchPy" }
        & py -3 $PatchPy $localSrc $localOut --restore
    } else {
        & py -3 $PatchPy $localSrc $localOut --dylib $RemoteDylib
    }
    if ($LASTEXITCODE -ne 0) { throw "patch_mad_launchd.py failed" }

    & $pscp -batch -P $Port -l root -pw alpine -hostkey $hk `
        $localOut "root@127.0.0.1:$PatchedRemote"
    if ($LASTEXITCODE -ne 0) { throw "pscp upload patched plist failed" }

    $installScript = @"
set -e
SRC='$srcPlist'
BAK='$BackupRemote'
PATCH='$PatchedRemote'
mount -uw / 2>/dev/null || true
if [ ! -f "`$BAK" ]; then cp -f "`$SRC" "`$BAK"; echo BACKUP_CREATED; else echo BACKUP_EXISTS; fi
chflags nouchg "`$SRC" 2>/dev/null || true
cp -f "`$PATCH" "`$SRC"
chmod 644 "`$SRC"
echo INSTALLED
ls -la "`$SRC" "`$BAK" 2>/dev/null || true
"@ -replace "`r`n", "`n"

    $installSh = Join-Path $WorkDir "install_mad_launchd.sh"
    [System.IO.File]::WriteAllText($installSh, $installScript, [Text.UTF8Encoding]::new($false))

    Write-Host "[install] patching launchd on device ..."
    & $plink -batch -ssh -P $Port -l root -pw alpine -hostkey $hk -m $installSh 127.0.0.1
    if ($LASTEXITCODE -ne 0) { throw "plink install script failed" }

    Write-Host ""
    if ($Restore) {
        Write-Host "OK restored launchd plist (DYLD keys removed). Reboot manual."
    } else {
        Write-Host "OK patched launchd plist."
        Write-Host "  dylib:  $RemoteDylib"
        Write-Host "  plist:  $srcPlist"
        Write-Host "  backup: $BackupRemote"
        Write-Host ""
        Write-Host "REBOOT MANUAL to load mobileactivationd with hook."
        Write-Host "AMFI may still block DYLD on platform daemons - check logs after boot."
    }
}
finally {
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
}
