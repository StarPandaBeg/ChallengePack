"""Real PowerShell installer tests; all files stay in disposable workspace fixtures."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRATCH = ROOT / "tests" / ".scratch"


class InstallerTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(exist_ok=True)
        self.temp = Path(tempfile.mkdtemp(prefix="game_", dir=SCRATCH))
        self.game = self.temp / "Игра с пробелами"
        self.mod = self.game / "ChallengePack"
        self.src = self.mod / "src"
        self.src.mkdir(parents=True)
        self.exe = self.game / "Buckshot Roulette.exe"
        self.exe.touch()
        self.cfg = self.game / "override.cfg"
        shutil.copyfile(ROOT / "ChallengePack" / "src" / "modcfg.ps1", self.src / "modcfg.ps1")
        for name in ("install.bat", "uninstall.bat"):
            shutil.copyfile(ROOT / "ChallengePack" / name, self.mod / name)
        (self.src / "challengepack.gd").touch()

    def tearDown(self):
        assert self.temp.resolve().is_relative_to(SCRATCH.resolve())
        shutil.rmtree(self.temp)

    def run_installer(self, action, success=True):
        process = subprocess.run(
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
             str(self.src / "modcfg.ps1"), "-Action", action], capture_output=True)
        self.assertEqual(process.returncode == 0, success, process.stderr.decode(errors="replace"))

    def test_clean_install_idempotence_uninstall(self):
        self.run_installer("install")
        first = self.cfg.read_bytes()
        self.assertIn("Игра с пробелами", first.decode("utf-8"))
        self.assertIn("/ChallengePack/src/challengepack.gd", first.decode("utf-8"))
        self.run_installer("install")
        self.assertEqual(first, self.cfg.read_bytes())
        self.run_installer("uninstall")
        self.assertFalse(self.cfg.exists())
        self.run_installer("uninstall")

    def test_other_sections_and_mods_survive(self):
        original = '; мой комментарий\r\n[autoload]\r\nOtherMod="*C:/other.gd"\r\n\r\n[rendering]\r\nChallengePack="leave me"\r\nquality=2\r\n'
        self.cfg.write_bytes(original.encode("utf-8"))
        self.run_installer("install")
        self.run_installer("install")
        installed = self.cfg.read_bytes().decode("utf-8")
        self.assertEqual(installed.count('ChallengePack="*'), 1)
        self.assertIn('[rendering]\r\nChallengePack="leave me"', installed)
        self.run_installer("uninstall")
        self.assertEqual(self.cfg.read_bytes(), original.encode("utf-8"))

    def test_without_autoload_preserves_existing_settings(self):
        self.cfg.write_text('[display]\nsize=123\n', encoding="utf-8")
        self.run_installer("install")
        self.run_installer("uninstall")
        self.assertIn('[display]\nsize=123\n', self.cfg.read_text(encoding="utf-8"))
        self.assertNotIn("[autoload]", self.cfg.read_text(encoding="utf-8"))

    def test_duplicate_own_entries_removed(self):
        self.cfg.write_text('[autoload]\nChallengePack="*old"\n ChallengePack = "*older"\nOther="*keep"\n', encoding="utf-8")
        self.run_installer("install")
        result = self.cfg.read_text(encoding="utf-8")
        self.assertEqual(result.count("ChallengePack="), 1)
        self.assertNotIn("older", result)
        self.assertIn('Other="*keep"', result)

    def test_missing_executable_does_not_change_config(self):
        self.exe.unlink()
        self.run_installer("install", success=False)
        self.assertFalse(self.cfg.exists())

    def test_missing_script_does_not_change_config(self):
        (self.src / "challengepack.gd").unlink()
        self.run_installer("install", success=False)
        self.assertFalse(self.cfg.exists())

    def test_batch_entrypoints_delegate_to_src(self):
        for name in ("install.bat", "uninstall.bat"):
            process = subprocess.run(
                ["cmd.exe", "/d", "/c", str(self.mod / name), "/q"], capture_output=True)
            self.assertEqual(process.returncode, 0, process.stderr.decode(errors="replace"))
            if name == "install.bat":
                self.assertIn("/src/challengepack.gd", self.cfg.read_text(encoding="utf-8"))
        self.assertFalse(self.cfg.exists())


if __name__ == "__main__":
    unittest.main()
