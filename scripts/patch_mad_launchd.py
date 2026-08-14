#!/usr/bin/env python3
"""Patch or restore com.apple.mobileactivationd LaunchDaemon plist (DYLD hook)."""
from __future__ import annotations

import argparse
import plistlib
import shutil
import sys
from datetime import datetime
from pathlib import Path

DEFAULT_DYLIB = "/mnt2/tmp/libiokit_spoof.dylib"


def load_plist(path: Path) -> tuple[dict, int]:
    data = path.read_bytes()
    pl = plistlib.loads(data)
    fmt = plistlib.FMT_BINARY if data.startswith(b"bplist") else plistlib.FMT_XML
    return pl, fmt


def save_plist(path: Path, pl: dict, fmt: int) -> None:
    with path.open("wb") as f:
        plistlib.dump(pl, f, fmt=fmt)


def patch_plist(src: Path, dst: Path, dylib: str) -> None:
    pl, fmt = load_plist(src)
    env = dict(pl.get("EnvironmentVariables") or {})
    env["DYLD_INSERT_LIBRARIES"] = dylib
    env["DYLD_FORCE_FLAT_NAMESPACE"] = "1"
    pl["EnvironmentVariables"] = env
    save_plist(dst, pl, fmt)


def restore_plist(src: Path, dst: Path) -> None:
    pl, fmt = load_plist(src)
    env = dict(pl.get("EnvironmentVariables") or {})
    env.pop("DYLD_INSERT_LIBRARIES", None)
    env.pop("DYLD_FORCE_FLAT_NAMESPACE", None)
    if env:
        pl["EnvironmentVariables"] = env
    else:
        pl.pop("EnvironmentVariables", None)
    save_plist(dst, pl, fmt)


def main() -> int:
    ap = argparse.ArgumentParser(description="Patch mobileactivationd launchd plist")
    ap.add_argument("src", type=Path, help="source plist")
    ap.add_argument("dst", type=Path, help="output plist")
    ap.add_argument("--dylib", default=DEFAULT_DYLIB)
    ap.add_argument("--restore", action="store_true", help="remove DYLD env keys")
    args = ap.parse_args()

    if not args.src.is_file():
        print(f"ERROR: missing {args.src}", file=sys.stderr)
        return 1

    if args.restore:
        restore_plist(args.src, args.dst)
        print(f"restored (no DYLD): {args.dst}")
    else:
        patch_plist(args.src, args.dst, args.dylib)
        print(f"patched DYLD_INSERT_LIBRARIES={args.dylib}")
        print(f"output: {args.dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
