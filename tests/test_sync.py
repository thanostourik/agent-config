import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        shutil.copytree(Path(__file__).resolve().parents[1], self.repo,
                        ignore=shutil.ignore_patterns(".git", ".generated", "__pycache__"))

    def run_sync(self, *args, expected=0):
        result = subprocess.run([str(self.repo / "sync"), "--home", str(self.home), *args],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout

    def test_empty_scaffold_does_not_touch_existing_configuration(self):
        target = self.home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        target.write_text("existing instructions")
        self.run_sync("--apply")
        self.assertEqual(target.read_text(), "existing instructions")
        self.assertFalse((self.home / ".claude").exists())

    def test_preview_apply_and_repeat(self):
        (self.repo / "instructions/common.md").write_text("Shared rules\n")
        (self.repo / "instructions/codex.md").write_text("Codex rules\n")
        self.run_sync()
        self.assertFalse(self.home.exists())
        self.run_sync("--check", expected=1)
        self.run_sync("--apply")
        self.assertEqual((self.home / ".codex/AGENTS.md").read_text(),
                         "Shared rules\n\nCodex rules\n")
        for path in [".claude/CLAUDE.md", ".grok/AGENTS.md", ".config/opencode/AGENTS.md"]:
            self.assertEqual((self.home / path).read_text(), "Shared rules\n")
        self.assertEqual((self.repo / ".generated/cursor-user-rules.md").read_text(),
                         "Shared rules\n")
        self.run_sync("--check")

    def test_conflicts_block_all_writes_and_replacement_backs_up_symlink(self):
        (self.repo / "instructions/common.md").write_text("New rules")
        original = self.root / "original.md"
        original.write_text("Old rules")
        target = self.home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        target.symlink_to(original)
        self.run_sync("--apply", expected=2)
        self.assertFalse((self.home / ".claude").exists())
        self.run_sync("--apply", "--replace-existing")
        self.assertFalse(target.is_symlink())
        self.assertEqual(original.read_text(), "Old rules")
        backups = list(target.parent.glob("AGENTS.md.backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertTrue(backups[0].is_symlink())

    def test_skills_agents_and_profile_isolation(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir()
        (skill / "SKILL.md").write_text("Example skill")
        script = skill / "run.sh"
        script.write_text("#!/bin/sh\nexit 0\n")
        script.chmod(0o755)
        (self.repo / "agents/claude-code/codex-runner.md").write_text("Agent instructions")
        (self.repo / "profiles/fable-with-sol.md").write_text("Fable-only instructions")
        self.run_sync("--apply")
        installed = self.home / ".agents/skills/example/run.sh"
        subprocess.run([str(installed)], check=True, timeout=5)
        self.assertTrue((self.home / ".claude/agents/codex-runner.md").is_file())
        self.assertFalse((self.home / ".claude/skills/codex-analyze").exists())
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.run_sync("--check")


if __name__ == "__main__":
    unittest.main()
