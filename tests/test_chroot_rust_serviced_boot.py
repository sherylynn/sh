#!/usr/bin/env python3
"""Termux CLI must never become a second CHROOT compositor/desktop owner."""
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
CLI=(ROOT/"termux/chroot/cli.sh").read_text()
ALL=(ROOT/"termux/chroot/termux_all_in_one.sh").read_text()

class TermuxAllInOneRustServicedTest(unittest.TestCase):
    def test_shells_parse(self):
        for path in ("termux/chroot/cli.sh","termux/chroot/termux_all_in_one.sh"):
            r=subprocess.run(["bash","-n",str(ROOT/path)],capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr)

    def test_old_newhome_sysv_entries_are_filtered_but_other_rc3_remains(self):
        self.assertIn('S[0-9][0-9]newhome-serviced|S[0-9][0-9]newhome-linux-services) continue', CLI)
        self.assertIn('K[0-9][0-9]newhome-serviced|K[0-9][0-9]newhome-linux-services) continue', CLI)
        self.assertIn('for item in ${services}; do',CLI)
        self.assertNotIn("/etc/init.d/newhome-linux-services restart", CLI)

    def test_explicit_start_reattaches_only_to_supervised_owner(self):
        self.assertIn("start_managed_chroot_services",ALL)
        self.assertIn("/usr/bin/newhome-serviced-bootstrap start",ALL)
        self.assertIn("newhome-systemctl daemon-reload",ALL)
        for unit in ("newhome-linux-runtime-bridge.service",
                     "newhome-linux-service-manager-bridge.service",
                     "newhome-wayland-core.service", "newhome-wayland-desktop.service"):
            self.assertIn(unit,ALL)
        self.assertIn("newhome-systemctl is-active",ALL)
        self.assertIn("/etc/newhome/wayland-owner.conf",ALL)

    def test_no_u_compositor_or_duplicate_xfce_process_is_started(self):
        self.assertNotIn("-a com.example.customlauncher.action.LINUX_RUNTIME_ENSURE", ALL)
        for bad in ("pkill -TERM -x xfce4-session","pkill -TERM -x xfdesktop",
                    "nohup setsid /usr/bin/dbus-run-session",
                    "start_newhome_compositor()", "start_xfce_wayland_session()",
                    "mount_newhome_x11_runtime()"):
            self.assertNotIn(bad,ALL)

    def test_ghostlock_root_wrapper_also_stops_managed_services_before_umount(self):
        root_wrapper=(ROOT/"termux/chroot/termux_all_in_one_root.sh").read_text()
        self.assertIn("stop_managed_chroot_services",root_wrapper)
        self.assertLess(root_wrapper.index("stop_managed_chroot_services"),
                        root_wrapper.index("stop_chroot_container ||"))
        self.assertNotIn("stop_chroot_container 2>/dev/null || true",root_wrapper)

    def test_stop_is_explicit_supervised_disable_and_not_casual_window_close(self):
        self.assertIn("stop_managed_chroot_services",ALL)
        self.assertIn('newhome-systemctl disable "$unit"',ALL)
        self.assertIn('newhome-systemctl stop "$unit"',ALL)
        self.assertIn('/usr/bin/newhome-serviced-bootstrap stop',ALL)
        self.assertNotIn("stop_newhome_compositor()",ALL)
        self.assertNotIn("stop_newhome_wayland_desktop()",ALL)

if __name__=="__main__":
    unittest.main()
