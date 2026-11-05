#!/usr/bin/env python3
"""Execute the real transport startup body against isolated Unix sockets/processes."""
import os
import pathlib
import signal
import socket
import subprocess
import tempfile
import time
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / "termux/chroot/termux_all_in_one.sh"

class WaylandTransportRecovery(unittest.TestCase):
    def fixture(self, stalled=False):
        temp = tempfile.TemporaryDirectory(prefix="nh-transport-test-")
        self.addCleanup(temp.cleanup)
        root = pathlib.Path(temp.name)
        run = root / "run"
        run.mkdir()
        acceptor = root / "acceptor"
        if stalled:
            acceptor.write_text("#!/bin/sh\nexec sleep 60\n")
        else:
            acceptor.write_text("#!/usr/bin/python3\nimport socket,sys,time\ns=socket.socket(socket.AF_UNIX);s.bind(sys.argv[1]);s.listen();time.sleep(60)\n")
        acceptor.chmod(0o755)
        helper = root / "run-helper"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        (root / "allocator").touch()
        source = SOURCE.read_text().split("start_newhome_wayland_acceptor() {", 1)[1]
        body = source.split("chroot_exec -u root '", 1)[1].split("\n  ' || error", 1)[0]
        for old, new in {
            "/run/newhome-compositor": str(run),
            "/usr/bin/newhome-wayland-acceptor": str(acceptor),
            "/usr/bin/newhome-wayland-run": str(helper),
            "/usr/lib/newhome-container/libnewhome-wayland-shm-allocator.so": str(root / "allocator"),
            "/tmp/newhome-wayland-acceptor.log": str(root / "log"),
            'sleep 0.1': 'sleep 0.01',
            'sleep 0.05': 'sleep 0.005',
            '"$attempt" -lt 30': '"$attempt" -lt 2',
            '"$i" -lt 20': '"$i" -lt 5',
        }.items():
            body = body.replace(old, new)
        def cleanup():
            hint = run / "wayland-acceptor.pid"
            if hint.exists():
                pid = int(hint.read_text())
                try:
                    os.kill(pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
        self.addCleanup(cleanup)
        return root, run, body

    def execute(self, body):
        return subprocess.run(["bash", "-c", body], capture_output=True, text=True, timeout=5)

    def test_live_listener_is_reused_and_child_does_not_hold_lifecycle_lock(self):
        root, run, body = self.fixture()
        first = self.execute(body)
        self.assertEqual(first.returncode, 0, first.stderr)
        pid = (run / "wayland-acceptor.pid").read_text()
        inode = (run / "wayland-0").stat().st_ino
        second = self.execute(body)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual((run / "wayland-0").stat().st_ino, inode)
        self.assertEqual((run / "wayland-acceptor.pid").read_text(), pid)
        self.assertFalse((run / "wayland-acceptor.pid.new").exists())

    def test_stale_socket_is_replaced_without_a_listener(self):
        root, run, body = self.fixture()
        stale = socket.socket(socket.AF_UNIX)
        stale.bind(str(run / "wayland-0"))
        stale.close()
        result = self.execute(body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertGreater(int((run / "wayland-acceptor.pid").read_text()), 1)

    def test_live_but_unready_child_is_killed_and_startup_is_bounded(self):
        root, run, body = self.fixture(stalled=True)
        started = time.monotonic()
        result = self.execute(body)
        self.assertNotEqual(result.returncode, 0)
        self.assertLess(time.monotonic() - started, 4)
        self.assertFalse((run / "wayland-acceptor.pid").exists())

if __name__ == "__main__":
    unittest.main()
