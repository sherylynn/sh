#!/usr/bin/env python3
"""Bidirectional NewHome Android <-> chroot X11 clipboard bridge.

Android side: NewHome LinuxClipboardBridge on 127.0.0.1:4715.
Linux side: X11 CLIPBOARD via xclip.

The X11 CLIPBOARD is intentionally the merge point. x11vnc/noVNC already maps
VNC clipboard messages to the X selection, so a remote PC can participate
without a second VNC-specific protocol.
"""

from __future__ import annotations

import base64
import fcntl
import logging
import os
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

HOST = os.environ.get("NEWHOME_CLIPBOARD_HOST", "127.0.0.1")
PORT = int(os.environ.get("NEWHOME_CLIPBOARD_PORT", "4715"))
POLL_SECONDS = float(os.environ.get("NEWHOME_CLIPBOARD_POLL", "0.35"))
MAX_PAYLOAD_BYTES = 1024 * 1024
CONNECT_TIMEOUT = 2.0
RECONNECT_SECONDS = 1.0
LOCK_PATH = Path("/tmp/newhome-clipboard-bridge.lock")
LOG_PATH = Path("/tmp/newhome-clipboard-bridge.log")

stop_event = threading.Event()
android_snapshot_ready = threading.Event()
state_lock = threading.Lock()
last_x_text: str | None = None


def configure_logging() -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stderr)]
    try:
        handlers.append(logging.FileHandler(LOG_PATH, encoding="utf-8"))
    except OSError:
        pass
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=handlers,
    )


def acquire_single_instance_lock():
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_file = LOCK_PATH.open("w")
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        logging.info("another clipboard bridge is already running")
        lock_file.close()
        return None
    lock_file.write(str(os.getpid()))
    lock_file.flush()
    return lock_file


def require_environment() -> None:
    if not os.environ.get("DISPLAY"):
        raise RuntimeError("DISPLAY is not set")
    try:
        subprocess.run(
            ["xclip", "-version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
            check=False,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("xclip is not installed") from exc


def read_x_clipboard() -> str | None:
    try:
        result = subprocess.run(
            ["xclip", "-selection", "clipboard", "-out"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    if len(result.stdout) > MAX_PAYLOAD_BYTES:
        logging.warning("X clipboard is larger than %d bytes; ignored", MAX_PAYLOAD_BYTES)
        return None
    return result.stdout.decode("utf-8", errors="replace")


def write_x_clipboard(text: str) -> bool:
    payload = text.encode("utf-8")
    if len(payload) > MAX_PAYLOAD_BYTES:
        logging.warning("Android clipboard is larger than %d bytes; ignored", MAX_PAYLOAD_BYTES)
        return False
    try:
        result = subprocess.run(
            ["xclip", "-selection", "clipboard", "-in"],
            input=payload,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        logging.warning("failed to write X clipboard: %s", exc)
        return False
    return result.returncode == 0


def connect_bridge():
    sock = socket.create_connection((HOST, PORT), timeout=CONNECT_TIMEOUT)
    sock.settimeout(None)
    reader = sock.makefile("r", encoding="utf-8", newline="\n")
    writer = sock.makefile("w", encoding="utf-8", newline="\n")
    hello = reader.readline().rstrip("\r\n")
    if hello != "HELLO NEWHOME_CLIPBOARD 1":
        reader.close()
        writer.close()
        sock.close()
        raise RuntimeError(f"unexpected bridge greeting: {hello!r}")
    return sock, reader, writer


def decode_clip_line(line: str) -> str | None:
    if line == "EMPTY":
        return None
    if not line.startswith("CLIP "):
        return None
    encoded = line[5:]
    try:
        payload = base64.b64decode(encoded, validate=True) if encoded else b""
    except ValueError:
        logging.warning("received invalid base64 clipboard payload")
        return None
    if len(payload) > MAX_PAYLOAD_BYTES:
        logging.warning("received oversized Android clipboard payload")
        return None
    return payload.decode("utf-8", errors="replace")


def send_android_clipboard(text: str) -> bool:
    payload = text.encode("utf-8")
    if len(payload) > MAX_PAYLOAD_BYTES:
        return False
    encoded = base64.b64encode(payload).decode("ascii")
    sock = reader = writer = None
    try:
        sock, reader, writer = connect_bridge()
        writer.write(f"SET {encoded}\n")
        writer.flush()
        response = reader.readline().rstrip("\r\n")
        if response != "OK":
            logging.warning("NewHome rejected clipboard update: %s", response)
            return False
        return True
    except (OSError, RuntimeError) as exc:
        logging.debug("NewHome clipboard SET unavailable: %s", exc)
        return False
    finally:
        for obj in (writer, reader, sock):
            if obj is not None:
                try:
                    obj.close()
                except OSError:
                    pass


def android_watch_loop() -> None:
    global last_x_text
    while not stop_event.is_set():
        sock = reader = writer = None
        try:
            sock, reader, writer = connect_bridge()
            writer.write("WATCH\n")
            writer.flush()
            response = reader.readline().rstrip("\r\n")
            if response != "OK WATCH":
                raise RuntimeError(f"WATCH rejected: {response!r}")
            logging.info("connected to NewHome Android clipboard bridge on %s:%d", HOST, PORT)

            while not stop_event.is_set():
                line = reader.readline()
                if not line:
                    raise ConnectionError("NewHome clipboard watcher disconnected")
                line = line.rstrip("\r\n")
                if line == "EMPTY":
                    # Do not erase a useful Linux clipboard just because Android starts empty.
                    # Mark initialization complete so the Linux value may flow Android-ward.
                    android_snapshot_ready.set()
                    continue
                if line.startswith("ERR "):
                    logging.warning("NewHome clipboard watcher: %s", line)
                    android_snapshot_ready.set()
                    continue
                text = decode_clip_line(line)
                if text is None and line != "CLIP ":
                    continue

                with state_lock:
                    if text == last_x_text:
                        android_snapshot_ready.set()
                        continue
                    # Set state before xclip so the poller cannot echo our own write back.
                    last_x_text = text
                if write_x_clipboard(text or ""):
                    logging.info("Android -> X11 clipboard (%d chars)", len(text or ""))
                android_snapshot_ready.set()
        except (OSError, RuntimeError, ConnectionError) as exc:
            logging.debug("Android clipboard watcher unavailable: %s", exc)
        finally:
            for obj in (writer, reader, sock):
                if obj is not None:
                    try:
                        obj.close()
                    except OSError:
                        pass
        stop_event.wait(RECONNECT_SECONDS)


def x_poll_loop() -> None:
    global last_x_text
    # Prefer Android's current non-empty clipboard on startup. If NewHome is not
    # available yet, do not block forever; changes will still be retried later.
    android_snapshot_ready.wait(timeout=3.0)

    pending_text: str | None = None
    while not stop_event.is_set():
        text = read_x_clipboard()
        if text is not None:
            with state_lock:
                already_synced = text == last_x_text
            if not already_synced:
                pending_text = text

        if pending_text is not None and send_android_clipboard(pending_text):
            with state_lock:
                last_x_text = pending_text
            logging.info("X11 -> Android clipboard (%d chars)", len(pending_text))
            pending_text = None

        stop_event.wait(POLL_SECONDS)


def handle_signal(_signum, _frame) -> None:
    stop_event.set()


def main() -> int:
    configure_logging()
    lock_file = acquire_single_instance_lock()
    if lock_file is None:
        return 0

    try:
        require_environment()
    except RuntimeError as exc:
        logging.error("clipboard bridge cannot start: %s", exc)
        return 2

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    logging.info("starting NewHome clipboard bridge DISPLAY=%s", os.environ.get("DISPLAY"))
    watcher = threading.Thread(target=android_watch_loop, name="AndroidClipboardWatch", daemon=True)
    poller = threading.Thread(target=x_poll_loop, name="XClipboardPoll", daemon=True)
    watcher.start()
    poller.start()

    try:
        while not stop_event.wait(1.0):
            pass
    finally:
        logging.info("stopping NewHome clipboard bridge")
        # Keep lock_file referenced until shutdown so flock remains held.
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        lock_file.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
