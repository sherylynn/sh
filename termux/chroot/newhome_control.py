#!/usr/bin/env python3
"""Small chroot-side client for NewHome's localhost control bridge.

The important property is lifecycle direction: the request originates inside
chroot, but the actual restart is owned by NewHome/Android, which survives the
chroot being stopped. No trigger files or Termux watchdog are involved.
"""

from __future__ import annotations

import argparse
import os
import socket
import sys

HOST = os.environ.get("NEWHOME_CONTROL_HOST", "127.0.0.1")
PORT = int(os.environ.get("NEWHOME_CONTROL_PORT", "4716"))
HELLO = "HELLO NEWHOME_CONTROL 1"
TIMEOUT = float(os.environ.get("NEWHOME_CONTROL_TIMEOUT", "5"))
MAX_LINE = 4096


def read_line(stream) -> str:
    raw = stream.readline(MAX_LINE + 1)
    if not raw:
        raise RuntimeError("NewHome closed the control connection")
    if len(raw) > MAX_LINE:
        raise RuntimeError("NewHome control response is too large")
    return raw.decode("utf-8", errors="strict").rstrip("\r\n")


def request(command: str) -> str:
    with socket.create_connection((HOST, PORT), timeout=TIMEOUT) as sock:
        sock.settimeout(TIMEOUT)
        with sock.makefile("rb") as reader:
            greeting = read_line(reader)
            if greeting != HELLO:
                raise RuntimeError(f"unexpected NewHome greeting: {greeting!r}")
            sock.sendall(command.encode("ascii") + b"\n")
            return read_line(reader)


def main() -> int:
    parser = argparse.ArgumentParser(description="NewHome Linux control client")
    parser.add_argument("command", choices=("ping", "restart"))
    args = parser.parse_args()

    wire = {"ping": "PING", "restart": "RESTART"}[args.command]
    try:
        response = request(wire)
    except (OSError, UnicodeError, RuntimeError) as exc:
        print(f"NewHome control unavailable: {exc}", file=sys.stderr)
        return 1

    if args.command == "ping":
        if response != "PONG":
            print(f"NewHome rejected ping: {response}", file=sys.stderr)
            return 2
        print("NewHome control bridge: OK")
        return 0

    if response == "OK RESTARTING":
        print("NewHome accepted container restart; this chroot session may disconnect now.")
        return 0

    print(f"NewHome rejected restart: {response}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
