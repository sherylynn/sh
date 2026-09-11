#!/usr/bin/env python3
"""Bidirectional NewHome Android <-> chroot X11 clipboard bridge.

Android side: NewHome LinuxClipboardBridge on 127.0.0.1:4715.
Linux side: X11 CLIPBOARD via xclip.

Android/NewHome and Linux intentionally form one *remote clipboard domain* for
noVNC. Any real copy on either side converges here, while noVNC may temporarily
stage a controller (PC/Mac) clipboard into X11 immediately before a remote paste.

The bridge also publishes a small state file for the existing XFCE tray tooling
(or future diagnostics) so it can show where the latest remote-domain clipboard
change came from without storing the full clipboard contents.
"""

from __future__ import annotations

import base64
import fcntl
import hashlib
import json
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
STATE_PATH = Path(os.environ.get(
    "NEWHOME_CLIPBOARD_STATE_PATH",
    "/tmp/newhome-clipboard-state.json",
))

# Restart request written when NewHome sends CTRL RESTART. The bridge runs
# inside the chroot, so this path resolves to $CHROOT_DIR/root/.container_restart_request
# on the host, which the Termux-side watchdog (cli.sh watchdog) polls and turns
# into an actual stop+start of the container.
RESTART_REQUEST_PATH = Path(os.environ.get(
    "NEWHOME_RESTART_REQUEST_PATH",
    "/root/.container_restart_request",
))

stop_event = threading.Event()
android_snapshot_ready = threading.Event()
state_lock = threading.Lock()
metadata_lock = threading.Lock()
last_x_text: str | None = None
state_generation = 0
android_connected = False
state_record: dict[str, object | None] = {
    "origin": None,
    "direction": None,
    "pending": False,
    "sha256": None,
    "chars": None,
    "preview": None,
}


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


def _clipboard_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _clipboard_preview(text: str, limit: int = 80) -> str:
    compact = " ".join(text.replace("\x00", "").split())
    if len(compact) <= limit:
        return compact
    return compact[: limit - 1] + "…"


def publish_state(
    *,
    origin: str | None = None,
    direction: str | None = None,
    text: str | None = None,
    pending: bool | None = None,
    increment_generation: bool = False,
) -> None:
    """Write an atomic diagnostic state snapshot for tray/UI consumers.

    origin is deliberately `android` or `x11`.  At this layer an X11 owner may
    be a native Linux app *or* x11vnc after a PC injection; classifying it as
    `linux` would be false precision.  A future XFixes owner watcher can refine
    that provenance without changing the sync protocol.
    """

    global state_generation
    with metadata_lock:
        if increment_generation:
            state_generation += 1

        if origin is not None:
            state_record["origin"] = origin
        if direction is not None:
            state_record["direction"] = direction
        if pending is not None:
            state_record["pending"] = pending
        if text is not None:
            state_record.update({
                "sha256": _clipboard_hash(text),
                "chars": len(text),
                "preview": _clipboard_preview(text),
            })

        snapshot = {
            "version": 1,
            "pid": os.getpid(),
            "display": os.environ.get("DISPLAY"),
            "updated_at": time.time(),
            "generation": state_generation,
            "android_connected": android_connected,
            **state_record,
        }

        tmp = STATE_PATH.with_name(f"{STATE_PATH.name}.{os.getpid()}.tmp")
        try:
            STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
            tmp.write_text(
                json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            os.replace(tmp, STATE_PATH)
        except OSError as exc:
            logging.debug("failed to publish clipboard state: %s", exc)
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass


def set_android_connected(connected: bool) -> None:
    global android_connected
    changed = android_connected != connected
    android_connected = connected
    if changed:
        publish_state()


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


def request_container_restart() -> None:
    """Write a restart request file that a Termux-side watchdog consumes.

    The bridge runs inside the chroot; writing here lands at
    $CHROOT_DIR/root/.container_restart_request on the host, which the
    termux watchdog (cli.sh watchdog) polls and turns into stop+start.
    A concurrent request from the same loop is harmless: atomic rename avoids
    the watchdog consuming a half-written file.
    """
    try:
        RESTART_REQUEST_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = RESTART_REQUEST_PATH.with_name(RESTART_REQUEST_PATH.name + ".tmp")
        tmp.write_text(str(os.getpid()), encoding="utf-8")
        os.replace(tmp, RESTART_REQUEST_PATH)
        logging.info("wrote container restart request: %s", RESTART_REQUEST_PATH)
    except OSError as exc:
        logging.error("failed to write container restart request: %s", exc)


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
            set_android_connected(True)
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
                    android_snapshot_ready.set()
                    continue
                if line.startswith("ERR "):
                    logging.warning("NewHome clipboard watcher: %s", line)
                    android_snapshot_ready.set()
                    continue
                if line == "CTRL RESTART":
                    request_container_restart()
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
                    publish_state(
                        origin="android",
                        direction="android->x11",
                        text=text or "",
                        increment_generation=True,
                    )
                android_snapshot_ready.set()
        except (OSError, RuntimeError, ConnectionError) as exc:
            logging.debug("Android clipboard watcher unavailable: %s", exc)
        finally:
            set_android_connected(False)
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
    pending_announced = False
    while not stop_event.is_set():
        text = read_x_clipboard()
        if text is not None:
            with state_lock:
                already_synced = text == last_x_text
            if not already_synced and text != pending_text:
                pending_text = text
                pending_announced = False

        if pending_text is not None:
            if not pending_announced:
                publish_state(
                    origin="x11",
                    direction="x11->android",
                    text=pending_text,
                    pending=True,
                )
                pending_announced = True

            if send_android_clipboard(pending_text):
                with state_lock:
                    last_x_text = pending_text
                logging.info("X11 -> Android clipboard (%d chars)", len(pending_text))
                publish_state(
                    origin="x11",
                    direction="x11->android",
                    text=pending_text,
                    pending=False,
                    increment_generation=True,
                )
                pending_text = None
                pending_announced = False

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
    publish_state()
    watcher = threading.Thread(target=android_watch_loop, name="AndroidClipboardWatch", daemon=True)
    poller = threading.Thread(target=x_poll_loop, name="XClipboardPoll", daemon=True)
    watcher.start()
    poller.start()

    try:
        while not stop_event.wait(1.0):
            pass
    finally:
        logging.info("stopping NewHome clipboard bridge")
        set_android_connected(False)
        publish_state()
        # Keep lock_file referenced until shutdown so flock remains held.
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        lock_file.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
