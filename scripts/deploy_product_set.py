#!/usr/bin/env python3
"""Deploy product_set tool — direct IOKit :/product read/set (no DYLD)."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

PLINK = Path(r"C:\Program Files\PuTTY\plink.exe")
PSCP = Path(r"C:\Program Files\PuTTY\pscp.exe")
SSH_HOST = "127.0.0.1"
SSH_PORT = 2222
SSH_USER = "root"
SSH_PASS = "alpine"
HOSTKEY = "SHA256:lb9y8xaKPkXl5gUgA+WHH5TbDlRwWZ6Io7BBLbX+PuE="

REMOTE_BIN = "/mnt2/tmp/product_set"
DEFAULT_LOCAL = Path(__file__).resolve().parent.parent / "product_set"


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def plink(cmd: str) -> str:
    r = run(
        [
            str(PLINK), "-batch", "-ssh", "-P", str(SSH_PORT),
            "-l", SSH_USER, "-pw", SSH_PASS, "-hostkey", HOSTKEY,
            SSH_HOST, cmd,
        ]
    )
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        raise RuntimeError(out.strip() or f"plink exit {r.returncode}")
    return out.strip()


def pscp_up(local: Path, remote: str) -> None:
    r = run(
        [
            str(PSCP), "-batch", "-P", str(SSH_PORT),
            "-l", SSH_USER, "-pw", SSH_PASS, "-hostkey", HOSTKEY,
            str(local), f"{SSH_USER}@{SSH_HOST}:{remote}",
        ]
    )
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout or "pscp failed").strip())


def main() -> int:
    ap = argparse.ArgumentParser(description="IOKit :product direct read/set")
    ap.add_argument("--binary", type=Path, default=DEFAULT_LOCAL)
    ap.add_argument("--read", action="store_true")
    ap.add_argument("--set", action="store_true")
    ap.add_argument("--upload-only", action="store_true")
    args = ap.parse_args()

    if not PLINK.is_file() or not PSCP.is_file():
        print("ERROR: install PuTTY plink/pscp")
        return 1

    if not args.read and not args.set and not args.upload_only:
        args.read = True

    if not args.binary.is_file():
        print(f"ERROR: missing {args.binary}")
        print("Build via GitHub Actions (product_set artifact) or Mac: scripts/build_local.sh")
        return 1

    print(plink("echo SSH_OK; uname -a"))
    pscp_up(args.binary, REMOTE_BIN)
    plink(f"chmod 755 '{REMOTE_BIN}' && file '{REMOTE_BIN}' 2>/dev/null || true")

    if args.upload_only:
        print(f"OK uploaded -> {REMOTE_BIN}")
        return 0

    if args.read:
        print("\n=== product_set read ===")
        print(plink(f"'{REMOTE_BIN}' read"))
    if args.set:
        print("\n=== product_set set (AP demotion) ===")
        print(plink(f"'{REMOTE_BIN}' set"))
        print("\nReboot MANUAL to normal iOS. Keys may not persist if SEP overwrites at boot.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
