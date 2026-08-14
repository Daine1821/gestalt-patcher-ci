# gestalt-patcher-ci

Build **iOS arm64e lab binaries** via **GitHub Actions** (macOS + Xcode).

| Artifact | Arch | Source | Lab use |
|---|---|---|---|
| `gestaltpatcher` | arm64e (default) | `poc.m` | Patch MobileGestalt plist on-device |
| `libiokit_spoof.dylib` | **arm64e** (required) | `iokit_spoof.m` | Hook IOKit demotion keys in `mobileactivationd` |

Repo: https://github.com/Daine1821/gestalt-patcher-ci

## Why arm64e for IOKit spoof

`mobileactivationd` on A13+ is **arm64e (PAC)**. An arm64-only dylib will not inject correctly. CI always builds `libiokit_spoof.dylib` as **arm64e**.

## iOS 26.5 lab (i11) - IOKit spoof

Static trace: `mobileactivationd` reads demotion via `copyDeviceTreeInt:key:` under **`:/product`** (kebab keys), not gestalt CacheData.

| Property | Spoof int (AP) |
|---|---|
| `certificate-production-status` | 0 |
| `effective-production-status-ap` | 1 |
| `certificate-security-mode` | 0 |
| `effective-security-mode-sep` | 0 |

**Ramdisk:** upload dylib only - `mobileactivationd` does not run; DYLD is stripped.

**Normal boot:** upload dylib + patch launchd plist, then **manual reboot**.

## GitHub Actions

1. Push to `master` / `main` or **Actions -> Run workflow**
2. Inputs:
   - `ios_min_version`: `15.0`
   - `lab_label`: `ios26.5-23F77-i12-1`
   - `build_target`: `iokit_spoof` | `gestaltpatcher` | `both`
   - `mach_arch`: `arm64e` (gestaltpatcher; iokit is always arm64e)
3. Download artifacts:
   - `libiokit_spoof-ios26.5-23F77-i12-1-arm64e`
   - `gestaltpatcher-ios26.5-23F77-i12-1`

## Windows lab workflow (i11 26.5)

### 1. Upload dylib only (ramdisk or anytime)

```powershell
cd gestalt-patcher-ci\scripts
.\upload_iokit_spoof.ps1 -Dylib "E:\Laboratorio aladin\hello_manual_deploy\03_staged\libiokit_spoof.dylib"
```

### 2. Patch mobileactivationd for normal boot

SSH must reach device with `/mnt1` or `/System` launchd plist visible.

```powershell
.\patch_mad_launchd.ps1 -Dylib "E:\Laboratorio aladin\hello_manual_deploy\03_staged\libiokit_spoof.dylib"
```

Creates backup: `/mnt2/tmp/com.apple.mobileactivationd.plist.bak`

**Reboot manual** after patch. AMFI may still block DYLD on platform daemons.

### 3. Restore original launchd plist

```powershell
.\patch_mad_launchd.ps1 -Restore
```

## GestaltHax v2 (Pro Max 26.1 path)

```powershell
.\scripts\run_ramdisk_lab.ps1 -Binary .\gestaltpatcher
```

Based on [hanakim3945/gestalt_hax_v2](https://github.com/hanakim3945/gestalt_hax_v2).

## Local Mac build

```bash
./scripts/build_local.sh 15.0 both arm64e
```

## Push updates

```bash
git add .
git commit -m "Build arm64e iokit_spoof + mad launchd patch scripts"
git push origin master
```

Then run workflow on GitHub and download `libiokit_spoof-*-arm64e`.
