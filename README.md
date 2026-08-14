# gestalt-patcher-ci

Build **iOS arm64 lab binaries** via **GitHub Actions** (macOS + Xcode).

| Artifact | Source | Lab use |
|---|---|---|
| `gestaltpatcher` | `poc.m` (GestaltHax v2) | Patch MobileGestalt plist on-device |
| `libiokit_spoof.dylib` | `iokit_spoof.m` | Hook IOKit demotion keys (iOS 26.5+) |

Repo: https://github.com/Daine1821/gestalt-patcher-ci

## iOS 26.5 lab (i11) — IOKit spoof

Static trace: `mobileactivationd` reads demotion via `copyDeviceTreeInt:key:` under **`:/product`** (kebab keys), not gestalt CacheData.

| Property | Spoof int (AP) |
|---|---|
| `certificate-production-status` | 0 |
| `effective-production-status-ap` | 1 |
| `certificate-security-mode` | 0 |
| `effective-security-mode-sep` | 0 |

**Important:** dylib is Mach-O binary, not a script. Default lab = **upload only** to `/mnt2/tmp/`; plist `DYLD_INSERT_LIBRARIES` on `mobileactivationd` is unreliable on ramdisk (AMFI).

## GitHub Actions

1. Push to `master` / `main` or **Actions → Run workflow**
2. Inputs:
   - `ios_min_version`: `15.0`
   - `lab_label`: `ios26.5-23F77-i12-1`
   - `build_target`: `iokit_spoof` | `gestaltpatcher` | `both`
3. Download artifacts:
   - `libiokit_spoof-ios26.5-23F77-i12-1`
   - `gestaltpatcher-...` (if built)

## Windows lab — upload dylib only

```powershell
# Copy artifact to repo folder, then:
.\scripts\upload_iokit_spoof.ps1 -Dylib .\libiokit_spoof.dylib
```

Copies to iPhone ramdisk: `/mnt2/tmp/libiokit_spoof.dylib` — **no plist patch**.

## GestaltHax v2 (Pro Max 26.1 path)

```powershell
.\scripts\run_ramdisk_lab.ps1 -Binary .\gestaltpatcher
```

Based on [hanakim3945/gestalt_hax_v2](https://github.com/hanakim3945/gestalt_hax_v2).

## Local Mac build

```bash
./scripts/build_local.sh 15.0 both
```

## Push updates

```bash
git add iokit_spoof.m .github/workflows/build-ios-patcher.yml README.md scripts/
git commit -m "Add libiokit_spoof.dylib CI build for iOS 26.5 demotion lab"
git push origin master
```

Then run workflow on GitHub.
