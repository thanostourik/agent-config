import json
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
        # Tests exercise the sync script, not the real configuration content:
        # start every test from an empty scaffold.
        for path in (self.repo / "instructions").glob("*.md"):
            path.write_text("")
        for folder in ("skills/shared", "skills/grok", "skills/opencode", "agents/claude-code",
                       "hooks", "bin"):
            shutil.rmtree(self.repo / folder, ignore_errors=True)

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
        self.assertEqual((self.home / ".cursor/rules/agent-config.mdc").read_text(),
                         "---\ndescription: Personal agent configuration\nglobs: \n"
                         "alwaysApply: true\n---\n\nShared rules\n")
        self.assertFalse((self.repo / ".generated").exists())
        self.run_sync("--check")

    def test_cursor_specific_rules_and_existing_rules_are_preserved(self):
        (self.repo / "instructions/common.md").write_text("Shared rules")
        (self.repo / "instructions/cursor.md").write_text("Cursor rules")
        existing = self.home / ".cursor/rules/other.mdc"
        existing.parent.mkdir(parents=True)
        existing.write_text("Existing rule")
        self.run_sync("--apply")
        target = self.home / ".cursor/rules/agent-config.mdc"
        self.assertTrue(target.read_text().endswith("Shared rules\n\nCursor rules\n"))
        self.assertEqual(existing.read_text(), "Existing rule")
        self.assertNotIn("Cursor rules", (self.home / ".claude/CLAUDE.md").read_text())
        (self.repo / "instructions/cursor.md").write_text("Updated Cursor rules")
        self.run_sync("--apply", expected=2)
        self.run_sync("--apply", "--replace-existing")
        self.assertTrue(target.read_text().endswith("Updated Cursor rules\n"))
        self.assertEqual(len(list(target.parent.glob("agent-config.mdc.backup-*"))), 1)
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
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        script = skill / "run.sh"
        script.write_text("#!/bin/sh\nexit 0\n")
        script.chmod(0o755)
        grok_skill = self.repo / "skills/grok/commit"
        grok_skill.mkdir(parents=True)
        (grok_skill / "SKILL.md").write_text("Grok skill")
        (self.repo / "skills/codex/empty").mkdir(parents=True)
        (self.repo / "skills/codex/empty/SKILL.md").write_text("")
        (self.repo / "agents/claude-code").mkdir(parents=True)
        (self.repo / "agents/claude-code/runner.md").write_text("Agent instructions")
        (self.repo / "agents/codex").mkdir(parents=True)
        (self.repo / "agents/codex/runner.toml").write_text("name = 'runner'")
        (self.repo / "profiles").mkdir()
        (self.repo / "profiles/fable-with-sol.md").write_text("Fable-only instructions")
        self.run_sync("--apply")
        installed = self.home / ".agents/skills/example/run.sh"
        subprocess.run([str(installed)], check=True, timeout=5)
        self.assertTrue((self.home / ".grok/skills/commit/SKILL.md").is_file())
        self.assertFalse((self.home / ".codex/skills").exists())
        self.assertTrue((self.home / ".claude/agents/runner.md").is_file())
        self.assertTrue((self.home / ".codex/agents/runner.toml").is_file())
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.run_sync("--check")

    def test_hooks_are_copied_or_merged_into_claude_settings(self):
        (self.repo / "hooks").mkdir()
        (self.repo / "hooks/codex.json").write_text('{"hooks": {}}\n')
        (self.repo / "hooks/claude-code.json").write_text('{"PostToolUse": []}')
        (self.repo / "hooks/grok.json").write_text('{"unsupported": true}')
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"theme": "dark", "hooks": {"Stop": []}}')
        self.run_sync("--apply", expected=2)
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual((self.home / ".codex/hooks.json").read_text(), '{"hooks": {}}\n')
        self.assertEqual(json.loads(settings.read_text()),
                         {"theme": "dark", "hooks": {"PostToolUse": []}})
        self.assertFalse((self.home / ".grok/hooks.json").exists())
        self.run_sync("--check")

    def test_skill_metadata_overrides_folder_and_copies_resources(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        contents = ('---\nname: example\nmetadata:\n  author: someone\n'
                    '  harness: "grok, opencode"\n---\nExample skill\n')
        (skill / "SKILL.md").write_text(contents)
        (skill / "run.sh").write_text("#!/bin/sh\necho skill\n")
        (skill / "run.sh").chmod(0o755)
        self.run_sync()
        self.assertFalse(self.home.exists())
        self.run_sync("--apply")
        for folder in (".grok/skills", ".config/opencode/skill"):
            installed = self.home / folder / "example"
            self.assertEqual((installed / "SKILL.md").read_text(), contents)
            result = subprocess.run([str(installed / "run.sh")], capture_output=True,
                                    text=True, check=True, timeout=5)
            self.assertEqual(result.stdout, "skill\n")
        self.assertFalse((self.home / ".agents").exists())
        self.run_sync("--check")

    def test_skill_metadata_ignores_other_fields_and_body_examples(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            '---\nname: example\nmetadata:\n  author: someone\n'
            'description: |\n  harness: example text\n---\n'
            'metadata:\n  harness: "grok"\n')
        self.run_sync("--apply")
        self.assertTrue((self.home / ".agents/skills/example/SKILL.md").exists())
        self.assertFalse((self.home / ".grok").exists())

    def test_invalid_skill_routing_blocks_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New instructions")
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        for field in ('  harness: [grok, opencode]', '  harness: grok',
                      '  harness: ""', '  harness: "grok, unknown"',
                      '  harness: "grok, "', '  harness: "grok, grok"',
                      '    harness: "grok"',
                      '  harness: "grok"\n  harness: "opencode"'):
            with self.subTest(field=field):
                (skill / "SKILL.md").write_text(f"---\nmetadata:\n{field}\n---\nSkill\n")
                self.run_sync("--apply", expected=2)
                self.assertFalse(self.home.exists())

    def test_duplicate_skill_destinations_block_all_writes(self):
        for tool in ("grok", "opencode"):
            skill = self.repo / "skills" / tool / "example"
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text(
                '---\nmetadata:\n  harness: "grok"\n---\nSkill\n')
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

    def test_scripts_install_executable_into_local_bin(self):
        (self.repo / "bin").mkdir()
        (self.repo / "bin/hello").write_text("#!/bin/sh\necho hi\n")
        self.run_sync("--apply")
        result = subprocess.run([str(self.home / ".local/bin/hello")],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.stdout, "hi\n")

    def test_clean_backups_removes_only_backups(self):
        (self.repo / "instructions/common.md").write_text("new")
        target = self.home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        target.write_text("old")
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual(len(list(target.parent.glob("AGENTS.md.backup-*"))), 1)
        self.run_sync("--clean-backups")
        self.assertEqual(list(target.parent.glob("AGENTS.md.backup-*")), [])
        self.assertEqual(target.read_text(), "new\n")

    def write_config(self, data):
        (self.repo / "config.json").write_text(json.dumps(data))

    def test_disabled_skill_and_hook_are_skipped(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        kept = self.repo / "skills/shared/kept"
        kept.mkdir(parents=True)
        (kept / "SKILL.md").write_text("Kept skill")
        (self.repo / "hooks").mkdir()
        (self.repo / "hooks/codex.json").write_text('{"hooks": {}}\n')
        (self.repo / "hooks/cursor.json").write_text('{"hooks": {}}\n')
        (self.repo / "agents/codex").mkdir(parents=True)
        (self.repo / "agents/codex/runner.toml").write_text("name = 'runner'")
        (self.repo / "agents/codex/other.toml").write_text("name = 'other'")
        self.write_config({
            "skills": {"example": {"enabled": False}, "kept": {"enabled": True}},
            "hooks": {"codex": {"enabled": False}},
            "agents": {"runner": {"enabled": False}},
        })
        self.run_sync("--apply")
        self.assertFalse((self.home / ".agents/skills/example").exists())
        self.assertTrue((self.home / ".agents/skills/kept/SKILL.md").is_file())
        self.assertFalse((self.home / ".codex/hooks.json").exists())
        self.assertTrue((self.home / ".cursor/hooks.json").is_file())
        self.assertFalse((self.home / ".codex/agents/runner.toml").exists())
        self.assertTrue((self.home / ".codex/agents/other.toml").is_file())

    def test_disable_removes_only_sync_installed_copies(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        kept = self.repo / "skills/shared/kept"
        kept.mkdir(parents=True)
        (kept / "SKILL.md").write_text("Kept skill")
        (self.repo / "hooks").mkdir()
        (self.repo / "hooks/codex.json").write_text('{"hooks": {}}\n')
        (self.repo / "hooks/claude-code.json").write_text('{"PostToolUse": []}')
        (self.repo / "agents/codex").mkdir(parents=True)
        (self.repo / "agents/codex/runner.toml").write_text("name = 'runner'")
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"theme": "dark", "hooks": {"Stop": []}}')
        self.run_sync("--apply", "--replace-existing")
        extra = self.home / ".agents/skills/unrelated/SKILL.md"
        extra.parent.mkdir(parents=True)
        extra.write_text("not from sync")
        self.write_config({
            "skills": {"example": {"enabled": False}},
            "hooks": {"codex": {"enabled": False}, "claude-code": {"enabled": False}},
            "agents": {"runner": {"enabled": False}},
        })
        self.run_sync("--apply", "--replace-existing")
        self.assertFalse((self.home / ".agents/skills/example").exists())
        self.assertTrue((self.home / ".agents/skills/kept/SKILL.md").is_file())
        self.assertEqual(extra.read_text(), "not from sync")
        self.assertFalse((self.home / ".codex/hooks.json").exists())
        self.assertFalse((self.home / ".codex/agents/runner.toml").exists())
        self.assertEqual(json.loads(settings.read_text()), {"theme": "dark"})
        self.assertTrue(list((self.home / ".agents/skills").glob("example.backup-*")))
        self.run_sync("--clean-backups")
        self.assertFalse(list((self.home / ".agents/skills").glob("example.backup-*")))

    def test_missing_config_leaves_everything_enabled(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        self.assertFalse((self.repo / "config.json").exists())
        self.run_sync("--apply")
        self.assertTrue((self.home / ".agents/skills/example/SKILL.md").is_file())

    def test_invalid_config_blocks_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New instructions")
        (self.repo / "config.json").write_text("{")
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())
        self.write_config({"skills": {"example": {"enabled": "no"}}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

    def test_example_config_lists_installable_skills_and_hooks(self):
        source = Path(__file__).resolve().parents[1]
        example = json.loads((source / "config.example.json").read_text())
        skills = {path.parent.name for path in (source / "skills").glob("*/*/SKILL.md")
                  if path.read_text().strip()}
        hooks = {path.stem for path in (source / "hooks").glob("*.json")}
        self.assertEqual(set(example["skills"]), skills)
        self.assertEqual(set(example["hooks"]), hooks)
        for entry in (*example["skills"].values(), *example["hooks"].values()):
            self.assertEqual(entry, {"enabled": True})


if __name__ == "__main__":
    unittest.main()
