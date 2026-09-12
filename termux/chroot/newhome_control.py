#!/usr/bin/env python3
"""Small chroot-side client for NewHome's privileged Linux control bridge.

The request originates inside chroot, but the actual restart is owned by
NewHome/Android, which survives the chroot being stopped. No trigger files,
clipboard control messages, or Termux watchdog are involved.

Control uses an Android/Linux abstract Unix-domain socket. NewHome verifies the
kernel peer credentials and accepts commands only from UID 0, so unrelated
Android apps cannot reach the privileged restart operation through localhost.
"""

from __future__ import annotations

import argparse
import os
import socket
import sys

SOCKET_NAME = os.environ.get("NEWHOME_CONTROL_SOCKET", "newhome_control_v1")
HELLO = "HELLO NEWHOME_CONTROL 1"
TIMEOUT = float(os.environ.get("NEWHOME_CONTROL_TIMEOUT", "20"))
MAX_LINE = 4096


def read_line(stream) -> str:
    raw = stream.readline(MAX_LINE + 1)
    if not raw:
        raise RuntimeError("NewHome closed the control connection")
    if len(raw) > MAX_LINE:
        raise RuntimeError("NewHome control response is too large")
    return raw.decode("utf-8", errors="strict").rstrip("\r\n")


def request(command: str) -> str:
    address = "\0" + SOCKET_NAME
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(TIMEOUT)
        sock.connect(address)
        with sock.makefile("rb") as reader:
            greeting = read_line(reader)
            if greeting == "ERR FORBIDDEN":
                raise PermissionError(
                    "NewHome accepts Linux control only from chroot root (UID 0)"
                )
            if greeting != HELLO:
                raise RuntimeError(f"unexpected NewHome greeting: {greeting!r}")
            sock.sendall(command.encode("ascii") + b"\n")
            return read_line(reader)


def main() -> int:
    parser = argparse.ArgumentParser(description="NewHome Linux control client")
    parser.add_argument(
        "command",
        choices=("ping", "restart", "restart-x11", "restart-wayland"),
        help="restart remains an alias for restart-x11 for backward compatibility",
    )
    args = parser.parse_args()

    if os.geteuid() != 0:
        print(
            "NewHome control must be called from the rooted chroot (UID 0).",
            file=sys.stderr,
        )
        return 4

    wire = {
        "ping": "PING",
        "restart": "RESTART",
        "restart-x11": "RESTART X11",
        "restart-wayland": "RESTART WAYLAND",
    }[args.command]
    try:
        response = request(wire)
    except (OSError, UnicodeError, RuntimeError, PermissionError) as exc:
        print(f"NewHome control unavailable: {exc}", file=sys.stderr)
        return 1

    if args.command == "ping":
        if response != "PONG":
            print(f"NewHome rejected ping: {response}", file=sys.stderr)
            return 2
        print("NewHome control bridge: OK")
        return 0

    if response == "OK RESTARTING":
        profile = "Wayland" if args.command == "restart-wayland" else "X11"
        print(
            f"NewHome accepted {profile} restart; this chroot session may disconnect now."
        )
        return 0

    errors = {
        "ERR ROOT_REQUIRED": (
            "NewHome needs root authorization from KernelSU/APatch/Magisk "
            "before it can restart Termux."
        ),
        "ERR ADB_LAUNCH_FAILED": (
            "NewHome internal ADB could not foreground Termux before restart. "
            "Check NewHome's internal ADB connection/authorization."
        ),
        "ERR BUSY": "Another NewHome container restart is already in progress.",
        "ERR UNKNOWN_PROFILE": "This NewHome build does not recognize the requested display profile.",
        "ERR START_FAILED": (
            "NewHome could not start the outer root restart process. "
            "For Wayland, also confirm termux_wayland_all_in_one.sh exists."
        ),
    }
    print(errors.get(response, f"NewHome rejected restart: {response}"), file=sys.stderr)
    return 3 if response == "ERR ROOT_REQUIRED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
