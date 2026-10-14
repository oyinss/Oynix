"""Exercise the notifier with isolated kernel/driver state and no real alerts."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "local/bin/reboot-notifier.sh"


class RebootNotifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.loaded = self.root / "nvidia-version"
        self.flag = self.root / "reboot-required"
        self.sent = self.root / "sent"
        self.env = {**os.environ, "XDG_RUNTIME_DIR": str(self.root),
                    "PATH": f"{self.bin}:/usr/bin:/bin",
                    "TEST_KERNEL": "7.2.9-arch1-1",
                    "TEST_PACKAGE": "7.2.9.arch1-1",
                    "TEST_DRIVER": "615.78.08", "TEST_SENT": str(self.sent)}
        commands = {
            "uname": 'printf "%s\\n" "$TEST_KERNEL"',
            "pacman": 'if [[ "$1" == -Qq ]]; then echo linux; else echo "linux $TEST_PACKAGE"; fi',
            "modinfo": '[[ -n "$TEST_DRIVER" ]] || exit 1; printf "%s\\n" "$TEST_DRIVER"',
            "notify-send": '[[ "${TEST_NOTIFY_FAIL:-0}" == 0 ]] || exit 1; printf "%s\\n" "$*" >> "$TEST_SENT"',
        }
        for name, body in commands.items():
            path = self.bin / name
            path.write_text("#!/bin/bash\n" + body + "\n")
            path.chmod(0o755)

    def run_notifier(self):
        # Redirect only filesystem probes; run the production Bash logic intact.
        text = SCRIPT.read_text().replace("/sys/module/nvidia/version", str(self.loaded))
        text = text.replace("/var/run/reboot-required", str(self.flag))
        return subprocess.run(["/bin/bash"], input=text, text=True, env=self.env,
                              capture_output=True)

    def alerts(self):
        return self.sent.read_text().splitlines() if self.sent.exists() else []

    def test_nvidia_mismatch_notifies_and_deduplicates(self):
        self.loaded.write_text("615.71.09\n")
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(len(self.alerts()), 1, "NVIDIA mismatch should emit an alert")
        self.assertIn("615.71.09", self.alerts()[0])
        self.assertIn("615.78.08", self.alerts()[0])
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(len(self.alerts()), 1, "Same mismatch should not repeat")

    def test_matching_nvidia_driver_does_not_notify(self):
        self.loaded.write_text("615.78.08\n")
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(self.alerts(), [])

    def test_no_loaded_nvidia_driver_does_not_notify(self):
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(self.alerts(), [])

    def test_failed_module_lookup_does_not_notify(self):
        self.loaded.write_text("615.71.09\n")
        self.env["TEST_DRIVER"] = ""
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(self.alerts(), [])

    def test_new_driver_update_notifies_again_in_same_boot(self):
        self.loaded.write_text("615.71.09\n")
        self.assertEqual(self.run_notifier().returncode, 0)
        self.env["TEST_DRIVER"] = "615.80.00"
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(len(self.alerts()), 2)

    def test_failed_delivery_does_not_mark_reason_as_sent(self):
        self.loaded.write_text("615.71.09\n")
        self.env["TEST_NOTIFY_FAIL"] = "1"
        self.assertNotEqual(self.run_notifier().returncode, 0)
        self.assertFalse((self.root / "reboot-notifier.done").exists())
        self.env["TEST_NOTIFY_FAIL"] = "0"
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(len(self.alerts()), 1)

    def test_kernel_update_still_notifies(self):
        self.env["TEST_PACKAGE"] = "7.2.10.arch1-1"
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertIn("newer kernel", self.alerts()[0])

    def test_reboot_required_flag_still_notifies(self):
        self.flag.touch()
        self.assertEqual(self.run_notifier().returncode, 0)
        self.assertEqual(len(self.alerts()), 1)


if __name__ == "__main__":
    unittest.main()
