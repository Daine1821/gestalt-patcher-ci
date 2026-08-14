# gestalt-patcher-ci

Build **GestaltHax v2** `gestaltpatcher` (arm64 iOS) via **GitHub Actions** on macOS.

Based on [hanakim3945/gestalt_hax_v2](https://github.com/hanakim3945/gestalt_hax_v2) — educational / lab use.

## Lab target (first test)

| Device | Build | GestaltHax |
|---|---|---|
| iPhone 11 Pro Max (`iPhone12,5`) | **23B85** (iOS 26.1) | v2 |

## One binary or many?

| Step | Per iOS version? |
|---|---|
| **Compile** `gestaltpatcher` arm64 | Usually **one binary** (`ios-min 15.0` is fine) |
| **Discover offset** (`gestalt_key_offset`) | **Yes — run on each iOS build** on the real device |
| **Patch plist** | Uses offset printed at runtime |

The binary links against **`libMobileGestalt.dylib` on the iPhone** when it runs — not at compile time. CI only builds the Mach-O; **execute on the phone in ramdisk**.

## GitHub Actions

1. Push this repo to GitHub.
2. **Actions → Build gestaltpatcher → Run workflow**
   - `ios_min_version`: `15.0` (default OK for 26.1)
   - `lab_label`: `ios26.1-23B85-iPhone12-5`
3. Download artifact **`gestaltpatcher-ios26.1-23B85-iPhone12-5`**

## Run on iPhone (ramdisk SSH)

```bash
chmod +x gestaltpatcher
cp /path/com.apple.MobileGestalt.plist /tmp/g.plist
./gestaltpatcher /tmp/g.plist
```

Stdout shows:

- `gestalt_key_offset = 0x...`
- `PATCH EffectiveSecurityModeAp @0x...`

Then deploy patched plist (keep **CacheUUID** / **CacheVersion**), optional `uchg`, reboot.

Windows helper (PuTTY):

```powershell
.\scripts\run_ramdisk_lab.ps1 -Binary .\gestaltpatcher
```

## Local Mac build

```bash
./scripts/build_local.sh 15.0
```

## Python patch (Windows lab)

After you have `gestalt_key_offset` from device output:

```powershell
cd "E:\Laboratorio aladin\hello_manual_deploy"
.\pull_gestalt.ps1
py -3 patch_gestalt_hax_v2.py --key-offset 0xXX
```

## References

- [GestaltHax writeup](https://hanakim3945.github.io/posts/gestalthax/)
- [gestalt_hax_v2](https://github.com/hanakim3945/gestalt_hax_v2)
