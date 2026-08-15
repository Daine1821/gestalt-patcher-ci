# gestalt-patcher-ci

Build **iOS arm64e lab binaries** via **GitHub Actions** (macOS + Xcode).

| Artifact | Arch | Signed | Lab use |
|---|---|---|---|
| `gestaltpatcher` | arm64e | no | Patch MobileGestalt plist (Python upload lab) |
| `libiokit_spoof.dylib` | arm64e | no | DYLD hook (blocked on platform mad) |
| **`product_set`** | **arm64e** | **yes (adhoc codesign)** | IOKit `:/product` read/set on ICH ramdisk |

Repo: https://github.com/Daine1821/gestalt-patcher-ci

## product_set + ICH trustcache

CI signs **`product_set` after compile** (same as local Mac):

```bash
codesign -s - --force --timestamp=none --entitlements entitlements/product_set.plist product_set
codesign -dv --verbose=4 product_set 2>&1 | grep CDHash
```

**Important:** add to `trustcache.img4` the CDHash of the **signed** binary from the artifact — not the unsigned build.

Artifact bundle includes:
- `product_set` (signed)
- `product_set_cdhash.txt`
- `product_set_codesign.txt`

### Ramdisk lab flow

1. Download `product_set-*-arm64e-signed`
2. Add `product_set_cdhash.txt` hash to your ICH trustcache
3. Boot ICH ramdisk chain
4. Upload signed `product_set` (do not re-sign locally)
5. `chmod 755 /mnt2/tmp/product_set && product_set read`

## iOS 26.5 demotion keys (`:/product`)

| Property | AP int |
|---|---|
| `certificate-production-status` | 0 |
| `effective-production-status-ap` | 1 |
| `certificate-security-mode` | 0 |
| `effective-security-mode-sep` | 0 |

## GitHub Actions

1. **Actions → Run workflow** (or push to `master`)
2. Inputs: `lab_label=ios26.5-23F77-i12-1`, `build_target=all`
3. Download:
   - `product_set-ios26.5-23F77-i12-1-arm64e-signed`
   - `build-info-*`

## Local Mac

```bash
./scripts/build_local.sh 15.0 product_set arm64e
# signs via scripts/sign_product_set.sh
cat product_set.cdhash.txt
```

## Other scripts

- `scripts/deploy_product_set.py` — upload + run read/set on ramdisk SSH
- `scripts/patch_mad_launchd.ps1` — DYLD plist (usually reverted on boot)
- `scripts/upload_iokit_spoof.ps1` — dylib upload only

Based on GestaltHax v2 / i11 26.5 IOKit static trace lab.
