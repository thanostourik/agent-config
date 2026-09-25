import json
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path


SKILL_DIRS = (
    ".claude/skills",
    ".codex/skills",
    ".grok/skills",
    ".config/opencode/skill",
    ".cursor/skills",
    ".agents/skills",
)


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.home = self.root / "home"
        self.backups = self.home / ".config/agent-config/backups"
        self.state = self.home / ".config/agent-config/state.json"
        shutil.copytree(Path(__file__).resolve().parents[1], self.repo,
                        ignore=shutil.ignore_patterns(".git", ".generated", "__pycache__",
                                                      "config.json"))
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
        self.run_sync("--apply")
        self.assertTrue(target.read_text().endswith("Updated Cursor rules\n"))
        self.assertFalse(self.backups.exists())
        self.run_sync("--check")

    def test_conflicts_block_all_writes_and_replacement_backs_up_symlink(self):
        (self.repo / "instructions/common.md").write_text("New rules")
        original = self.root / "original.md"
        original.write_text("New rules\n")
        target = self.home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        target.symlink_to(original)
        self.run_sync("--apply", expected=2)
        original.write_text("Old rules")
        self.run_sync("--apply", expected=2)
        self.assertFalse((self.home / ".claude").exists())
        self.run_sync("--apply", "--replace-existing")
        self.assertFalse(target.is_symlink())
        self.assertEqual(original.read_text(), "Old rules")
        backups = list(self.backups.glob("*/.codex/AGENTS.md"))
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
        for folder in SKILL_DIRS:
            self.assertTrue((self.home / folder / "example/SKILL.md").is_file())
        self.assertTrue((self.home / ".grok/skills/commit/SKILL.md").is_file())
        self.assertFalse((self.home / ".codex/skills/empty").exists())
        self.assertTrue((self.home / ".claude/agents/runner.md").is_file())
        self.assertTrue((self.home / ".codex/agents/runner.toml").is_file())
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.run_sync("--check")

    def write_hook(self, tool, name, data):
        folder = self.repo / "hooks" / tool
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{name}.json").write_text(json.dumps(data))

    def test_hooks_are_wrapped_per_tool_or_merged_into_claude_settings(self):
        self.write_hook("codex", "lint", {"PostToolUse": [{"hooks": [{"type": "command",
                                                                       "command": "lint"}]}]})
        self.write_hook("claude-code", "stop", {"Stop": [{"hooks": []}]})
        self.write_hook("cursor", "edit", {"afterFileEdit": [{"command": "fmt"}]})
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"theme": "dark", "hooks": {"Stop": []}}')
        self.run_sync("--apply", expected=2)
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual(json.loads((self.home / ".codex/hooks.json").read_text()),
                         {"hooks": {"PostToolUse": [{"hooks": [{"type": "command",
                                                                "command": "lint"}]}]}})
        self.assertEqual(json.loads((self.home / ".cursor/hooks.json").read_text()),
                         {"version": 1, "hooks": {"afterFileEdit": [{"command": "fmt"}]}})
        self.assertEqual(json.loads(settings.read_text()),
                         {"theme": "dark", "hooks": {"Stop": [{"hooks": []}]}})
        self.run_sync("--check")

    def test_hook_for_a_tool_without_hooks_stops_sync(self):
        self.write_hook("grok", "edit", {"afterFileEdit": []})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

    def test_shared_hook_is_translated_for_each_tool_and_merged_with_native_hooks(self):
        self.write_hook("shared", "render", {"event": "after-edit", "command": "render --hook",
                                             "timeout": 30})
        self.write_hook("shared", "cursor-only", {"event": "after-edit", "command": "fmt",
                                                  "harness": "cursor"})
        self.write_hook("codex", "lint", {"PostToolUse": [{"hooks": [{"type": "command",
                                                                       "command": "lint"}]}]})
        self.run_sync("--apply")
        render = {"type": "command", "command": "render --hook", "timeout": 30}
        self.assertEqual(
            json.loads((self.home / ".claude/settings.json").read_text())["hooks"],
            {"PostToolUse": [{"matcher": "Write|Edit|MultiEdit", "hooks": [render]}]})
        self.assertEqual(
            json.loads((self.home / ".codex/hooks.json").read_text())["hooks"],
            {"PostToolUse": [{"hooks": [{"type": "command", "command": "lint"}]},
                             {"hooks": [render]}]})
        self.assertEqual(
            json.loads((self.home / ".cursor/hooks.json").read_text())["hooks"],
            {"afterFileEdit": [{"command": "fmt"},
                               {"command": "render --hook", "timeout": 30}]})

    def test_shared_hook_rejects_unknown_event_harness_key_and_duplicate_name(self):
        self.write_hook("shared", "render", {"event": "on-boot", "command": "x"})
        self.run_sync("--apply", expected=2)
        self.write_hook("shared", "render", {"event": "after-edit", "command": "x",
                                             "harness": "grok"})
        self.run_sync("--apply", expected=2)
        self.write_hook("shared", "render", {"event": "after-edit", "command": "x",
                                             "timeouts": 30})
        self.run_sync("--apply", expected=2)
        self.write_hook("shared", "render", {"event": "after-edit", "command": "x"})
        self.write_hook("codex", "render", {"PostToolUse": []})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

    def test_config_naming_an_unknown_hook_stops_sync(self):
        self.write_hook("shared", "render", {"event": "after-edit", "command": "x"})
        self.write_config({"hooks": {"cursor": {"enabled": False}}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

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
        for folder in SKILL_DIRS:
            self.assertTrue((self.home / folder / "example/SKILL.md").exists())

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
        self.assertEqual([path.read_text() for path in self.backups.glob("*/.codex/AGENTS.md")],
                         ["old"])
        self.run_sync("--clean-backups")
        self.assertFalse(self.backups.exists())
        self.assertEqual(target.read_text(), "new\n")
        self.run_sync("--check")

    def add_skill(self, *files, harness=None):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True, exist_ok=True)
        metadata = f'metadata:\n  harness: "{harness}"\n' if harness else ""
        (skill / "SKILL.md").write_text(f"---\nname: example\n{metadata}---\nExample skill\n")
        for name in files:
            (skill / name).parent.mkdir(parents=True, exist_ok=True)
            (skill / name).write_text(name)
        return skill

    def test_file_removed_from_a_skill_is_deleted_and_unrecorded_files_stay(self):
        skill = self.add_skill("agents/openai.yaml")
        self.run_sync("--apply")
        installed = self.home / ".codex/skills/example"
        mine = installed / "notes.md"
        mine.write_text("not from sync")
        (skill / "agents/openai.yaml").unlink()
        self.run_sync("--apply")
        self.assertFalse((installed / "agents").exists())
        self.assertTrue((installed / "SKILL.md").is_file())
        self.assertEqual(mine.read_text(), "not from sync")
        self.assertFalse(self.backups.exists())
        self.assertNotIn("openai.yaml", self.state.read_text())
        self.run_sync("--check")

    def test_removed_sources_are_deleted(self):
        skill = self.add_skill()
        (self.repo / "agents/codex").mkdir(parents=True)
        agent = self.repo / "agents/codex/runner.toml"
        agent.write_text("name = 'runner'")
        (self.repo / "bin").mkdir()
        script = self.repo / "bin/hello"
        script.write_text("#!/bin/sh\n")
        other = self.home / ".local/bin/other"
        other.parent.mkdir(parents=True)
        other.write_text("not from sync")
        self.run_sync("--apply")
        shutil.rmtree(skill)
        agent.unlink()
        script.unlink()
        self.run_sync("--apply")
        for path in (".claude/skills/example", ".codex/agents/runner.toml", ".local/bin/hello"):
            self.assertFalse((self.home / path).exists(), path)
        self.assertTrue((self.home / ".claude/skills").is_dir())
        self.assertEqual(other.read_text(), "not from sync")

    def test_changed_harness_moves_the_skill(self):
        self.add_skill(harness="grok")
        self.run_sync("--apply")
        self.add_skill(harness="opencode")
        self.run_sync("--apply")
        self.assertFalse((self.home / ".grok/skills/example").exists())
        self.assertTrue((self.home / ".config/opencode/skill/example/SKILL.md").is_file())

    def test_hand_edited_files_need_the_flag_and_are_backed_up(self):
        skill = self.add_skill("extra.md", harness="grok")
        self.run_sync("--apply")
        installed = self.home / ".grok/skills/example"
        (installed / "SKILL.md").write_text("my edit")
        (installed / "extra.md").write_text("my other edit")
        (skill / "SKILL.md").write_text("Updated skill")
        (skill / "extra.md").unlink()
        self.run_sync("--apply", expected=2)
        self.assertEqual((installed / "SKILL.md").read_text(), "my edit")
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual((installed / "SKILL.md").read_text(), "Updated skill")
        self.assertFalse((installed / "extra.md").exists())
        saved = {path.name: path.read_text()
                 for path in self.backups.glob("*/.grok/skills/example/*")}
        self.assertEqual(saved, {"SKILL.md": "my edit", "extra.md": "my other edit"})

    def test_missing_file_and_lost_executable_bit_are_repaired(self):
        skill = self.add_skill("run.sh", harness="grok")
        (skill / "run.sh").chmod(0o755)
        self.run_sync("--apply")
        installed = self.home / ".grok/skills/example"
        (installed / "SKILL.md").unlink()
        (installed / "run.sh").chmod(0o644)
        self.run_sync("--check", expected=1)
        self.run_sync("--apply")
        self.assertTrue((installed / "SKILL.md").is_file())
        self.assertTrue((installed / "run.sh").stat().st_mode & 0o111)
        self.assertFalse(self.backups.exists())

    def test_first_run_records_identical_files_without_a_flag(self):
        self.add_skill(harness="grok")
        self.run_sync("--apply")
        self.state.unlink()
        self.run_sync("--check", expected=1)
        self.run_sync()
        self.assertFalse(self.state.exists())
        self.run_sync("--apply")
        self.assertIn(".grok/skills/example/SKILL.md", json.loads(self.state.read_text())["files"])
        self.run_sync("--check")

    def test_parent_that_is_a_file_blocks_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New rules")
        self.add_skill(harness="grok")
        parent = self.home / ".grok/skills/example"
        parent.parent.mkdir(parents=True)
        parent.write_text("a file where the skill folder goes")
        self.run_sync("--apply", "--replace-existing", expected=2)
        self.assertEqual(parent.read_text(), "a file where the skill folder goes")
        self.assertFalse((self.home / ".claude").exists())

    def test_parent_of_a_shared_file_that_is_a_file_blocks_all_writes(self):
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        parent = self.home / ".config/opencode"
        parent.parent.mkdir(parents=True)
        parent.write_text("a file where the folder goes")
        self.run_sync("--check", expected=2)
        self.run_sync("--apply", "--replace-existing", expected=2)
        self.assertFalse((self.home / ".claude.json").exists())

    def test_malformed_state_blocks_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New rules")
        self.state.parent.mkdir(parents=True)
        for contents in ("{", '{"files": {"../outside": "0"}, "entries": {}}',
                         '{"files": {".grok#/../../outside": "0"}, "entries": {}}',
                         '{"files": {"/etc/passwd": "0"}, "entries": {}}', '{"files": {}}'):
            with self.subTest(contents=contents):
                self.state.write_text(contents)
                self.run_sync("--apply", expected=2)
                self.assertFalse((self.home / ".claude").exists())

    def write_config(self, data):
        (self.repo / "config.json").write_text(json.dumps(data))

    def test_disabled_skill_and_hook_are_skipped(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        kept = self.repo / "skills/shared/kept"
        kept.mkdir(parents=True)
        (kept / "SKILL.md").write_text("Kept skill")
        self.write_hook("shared", "render", {"event": "after-edit", "command": "render"})
        self.write_hook("cursor", "fmt", {"afterFileEdit": [{"command": "fmt"}]})
        (self.repo / "agents/codex").mkdir(parents=True)
        (self.repo / "agents/codex/runner.toml").write_text("name = 'runner'")
        (self.repo / "agents/codex/other.toml").write_text("name = 'other'")
        self.write_config({
            "skills": {"example": {"enabled": False}, "kept": {"enabled": True}},
            "hooks": {"render": {"enabled": False}},
            "agents": {"runner": {"enabled": False}},
        })
        self.run_sync("--apply")
        for folder in SKILL_DIRS:
            self.assertFalse((self.home / folder / "example").exists())
            self.assertTrue((self.home / folder / "kept/SKILL.md").is_file())
        self.assertFalse((self.home / ".codex/hooks.json").exists())
        self.assertFalse((self.home / ".claude/settings.json").exists())
        self.assertEqual(json.loads((self.home / ".cursor/hooks.json").read_text())["hooks"],
                         {"afterFileEdit": [{"command": "fmt"}]})
        self.assertFalse((self.home / ".codex/agents/runner.toml").exists())
        self.assertTrue((self.home / ".codex/agents/other.toml").is_file())

    def test_disable_removes_only_sync_installed_copies(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        kept = self.repo / "skills/shared/kept"
        kept.mkdir(parents=True)
        (kept / "SKILL.md").write_text("Kept skill")
        self.write_hook("shared", "render", {"event": "after-edit", "command": "render"})
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
            "hooks": {"render": {"enabled": False}},
            "agents": {"runner": {"enabled": False}},
        })
        self.run_sync("--apply", "--replace-existing")
        for folder in SKILL_DIRS:
            self.assertFalse((self.home / folder / "example").exists())
        self.assertTrue((self.home / ".agents/skills/kept/SKILL.md").is_file())
        self.assertEqual(extra.read_text(), "not from sync")
        self.assertFalse((self.home / ".codex/hooks.json").exists())
        self.assertFalse((self.home / ".cursor/hooks.json").exists())
        self.assertFalse((self.home / ".codex/agents/runner.toml").exists())
        self.assertEqual(json.loads(settings.read_text()), {"theme": "dark"})
        self.assertFalse(list(self.backups.glob("*/.agents")))

    def test_missing_config_leaves_everything_enabled(self):
        skill = self.repo / "skills/shared/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Example skill")
        self.assertFalse((self.repo / "config.json").exists())
        self.run_sync("--apply")
        for folder in SKILL_DIRS:
            self.assertTrue((self.home / folder / "example/SKILL.md").is_file())

    def test_invalid_config_blocks_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New instructions")
        (self.repo / "config.json").write_text("{")
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())
        self.write_config({"skills": {"example": {"enabled": "no"}}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())
        self.write_config({"mcp": {"jira": {"enabled": "no"}}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())

    def test_example_config_lists_installable_skills_and_hooks(self):
        source = Path(__file__).resolve().parents[1]
        example = json.loads((source / "config.example.json").read_text())
        skills = {path.parent.name for path in (source / "skills").glob("*/*/SKILL.md")
                  if path.read_text().strip()}
        hooks = {path.stem for path in (source / "hooks").glob("*/*.json")}
        self.assertEqual(set(example["skills"]), skills)
        self.assertEqual(set(example["hooks"]), hooks)
        for entry in (*example["skills"].values(), *example["hooks"].values()):
            self.assertEqual(entry, {"enabled": True})
        self.assertEqual(example["mcp"]["jira"]["enabled"], True)
        self.assertEqual(example["mcp"]["jira"]["instances"],
                         {"work": {"url": "https://jira.example.com"}})

    def add_helper(self):
        source = Path(__file__).resolve().parents[1] / "bin/mcp-atlassian-start"
        dest = self.repo / "bin"
        dest.mkdir()
        shutil.copy(source, dest / "mcp-atlassian-start")
        (dest / "mcp-atlassian-start").chmod(0o755)

    def jira_config(self, instances, enabled=True):
        self.write_config({"mcp": {"jira": {"enabled": enabled, "instances": instances}}})

    def test_missing_config_does_not_touch_existing_mcp(self):
        target = self.home / ".cursor/mcp.json"
        target.parent.mkdir(parents=True)
        target.write_text('{"mcpServers": {"jira": {"command": "keep-me"}}}')
        self.assertFalse((self.repo / "config.json").exists())
        self.run_sync("--apply")
        self.assertEqual(json.loads(target.read_text())["mcpServers"]["jira"]["command"],
                         "keep-me")
        self.assertFalse(self.state.exists())

    def test_empty_jira_instances_do_not_create_mcp_files(self):
        self.add_helper()
        self.jira_config({})
        self.run_sync("--apply")
        self.assertFalse((self.home / ".cursor/mcp.json").exists())
        self.assertFalse((self.home / ".claude.json").exists())
        self.assertTrue((self.home / ".local/bin/mcp-atlassian-start").is_file())

    def test_one_jira_instance_installs_as_server_jira(self):
        self.add_helper()
        url = "https://jira.example.com"
        self.jira_config({"work": {"url": url}})
        self.home.mkdir()
        self.home.joinpath(".claude.json").write_text('{"theme": "dark"}')
        self.home.joinpath(".codex").mkdir(parents=True)
        self.home.joinpath(".codex/config.toml").write_text("[features]\nmemories = false\n")
        self.home.joinpath(".cursor").mkdir()
        self.home.joinpath(".cursor/mcp.json").write_text(
            '{"mcpServers": {"other": {"command": "keep"}}}')
        self.run_sync("--apply", "--replace-existing")
        helper = str(self.home / ".local/bin/mcp-atlassian-start")
        cursor = json.loads((self.home / ".cursor/mcp.json").read_text())
        self.assertEqual(cursor["mcpServers"]["other"]["command"], "keep")
        self.assertEqual(cursor["mcpServers"]["jira"]["command"], helper)
        self.assertEqual(cursor["mcpServers"]["jira"]["args"], [url])
        self.assertEqual(set(cursor["mcpServers"]["jira"]["env"]),
                         {"DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR"})
        claude = json.loads((self.home / ".claude.json").read_text())
        self.assertEqual(claude["theme"], "dark")
        self.assertEqual(claude["mcpServers"]["jira"]["args"], [url])
        opencode = json.loads((self.home / ".config/opencode/opencode.json").read_text())
        self.assertEqual(opencode["mcp"]["jira"]["type"], "local")
        self.assertEqual(opencode["mcp"]["jira"]["command"], [helper, url])
        self.assertEqual(opencode["mcp"]["jira"]["timeout"], 180000)
        grok = (self.home / ".grok/config.toml").read_text()
        self.assertIn("[mcp_servers.jira]", grok)
        self.assertIn("startup_timeout_sec = 180", grok)
        self.assertIn(f"args = [{json.dumps(url)}]", grok)
        codex = (self.home / ".codex/config.toml").read_text()
        self.assertIn("[features]", codex)
        self.assertIn("memories = false", codex)
        self.assertIn("[mcp_servers.jira]", codex)
        self.assertIn(".codex/config.toml#mcp_servers.jira",
                      json.loads(self.state.read_text())["entries"])
        result = subprocess.run([helper], capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage:", result.stderr)
        self.run_sync("--check")

    def test_two_jira_instances_use_keys_and_disable_removes_them(self):
        self.add_helper()
        self.jira_config({
            "work": {"url": "https://jira.example.com"},
            "other": {"url": "https://other.example.com"},
        })
        extra = self.home / ".cursor/mcp.json"
        extra.parent.mkdir(parents=True)
        extra.write_text('{"mcpServers": {"unrelated": {"command": "keep"}}}')
        self.run_sync("--apply", "--replace-existing")
        cursor = json.loads(extra.read_text())["mcpServers"]
        self.assertEqual(set(cursor), {"unrelated", "work", "other"})
        self.assertNotIn("jira", cursor)
        self.assertEqual(cursor["work"]["args"], ["https://jira.example.com"])
        self.assertEqual(cursor["other"]["args"], ["https://other.example.com"])
        self.jira_config({
            "work": {"url": "https://jira.example.com"},
            "other": {"url": "https://other.example.com"},
        }, enabled=False)
        self.run_sync("--apply", "--replace-existing")
        cursor = json.loads(extra.read_text())["mcpServers"]
        self.assertEqual(cursor, {"unrelated": {"command": "keep"}})
        self.assertEqual(json.loads(self.state.read_text())["entries"], {})

    def test_one_jira_instance_then_two_replaces_the_jira_name(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        self.run_sync("--apply")
        cursor = json.loads((self.home / ".cursor/mcp.json").read_text())["mcpServers"]
        self.assertEqual(set(cursor), {"jira"})
        self.jira_config({
            "work": {"url": "https://jira.example.com"},
            "other": {"url": "https://other.example.com"},
        })
        self.run_sync("--apply", "--replace-existing")
        cursor = json.loads((self.home / ".cursor/mcp.json").read_text())["mcpServers"]
        self.assertEqual(set(cursor), {"work", "other"})
        grok = (self.home / ".grok/config.toml").read_text()
        self.assertNotIn("[mcp_servers.jira]", grok)
        self.assertIn("[mcp_servers.work]", grok)
        self.assertIn("[mcp_servers.other]", grok)

    def test_clean_entry_update_needs_no_flag_and_backs_up_the_shared_file(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        claude = self.home / ".claude.json"
        claude.parent.mkdir(parents=True)
        claude.write_text('{"theme": "dark"}')
        legacy = self.home / ".config/agent-config/managed-mcp.json"
        legacy.parent.mkdir(parents=True)
        legacy.write_text('{"jira": ["jira"]}')
        self.run_sync("--apply")
        self.assertFalse(legacy.exists())
        shutil.rmtree(self.backups)
        claude.write_text(claude.read_text().replace('"dark"', '"light"'))
        self.jira_config({"work": {"url": "https://new.example.com"}})
        self.run_sync("--apply")
        data = json.loads(claude.read_text())
        self.assertEqual(data["theme"], "light")
        self.assertEqual(data["mcpServers"]["jira"]["args"], ["https://new.example.com"])
        saved = [json.loads(path.read_text()) for path in self.backups.glob("*/.claude.json")]
        self.assertEqual([item["mcpServers"]["jira"]["args"] for item in saved],
                         [["https://jira.example.com"]])
        self.run_sync("--check")

    def test_hand_written_jira_server_needs_the_flag(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        cursor = self.home / ".cursor/mcp.json"
        cursor.parent.mkdir(parents=True)
        cursor.write_text('{"mcpServers": {"jira": {"command": "mine"}}}')
        self.run_sync("--apply", expected=2)
        self.assertEqual(json.loads(cursor.read_text())["mcpServers"]["jira"], {"command": "mine"})
        self.assertFalse((self.home / ".claude.json").exists())
        cursor.write_text('{"mcpServers": []}')
        self.run_sync("--apply", "--replace-existing", expected=2)
        cursor.write_text('{"mcpServers": {"jira": {"command": "mine"}}}')
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual(json.loads(cursor.read_text())["mcpServers"]["jira"]["args"],
                         ["https://jira.example.com"])

    def test_disabling_hooks_leaves_an_unrecorded_hooks_key_alone(self):
        self.write_hook("claude-code", "stop", {"Stop": []})
        self.write_config({"hooks": {"stop": {"enabled": False}}})
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"hooks": {"Stop": []}}')
        self.run_sync("--apply", "--replace-existing")
        self.assertEqual(settings.read_text(), '{"hooks": {"Stop": []}}')

    def test_interrupted_run_needs_no_flag_on_the_next_run(self):
        self.add_helper()
        self.add_skill(harness="grok")
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        self.run_sync("--apply")
        before = self.state.read_text()
        (self.repo / "skills/shared/example/SKILL.md").write_text("Updated skill")
        self.jira_config({"work": {"url": "https://new.example.com"}})
        self.run_sync("--apply")
        after = self.state.read_text()
        self.state.write_text(before)
        self.run_sync("--check", expected=1)
        self.run_sync("--apply")
        self.assertEqual(self.state.read_text(), after)

    def test_toml_edit_keeps_comments_and_replaces_a_quoted_table(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        codex = self.home / ".codex/config.toml"
        codex.parent.mkdir(parents=True)
        codex.write_text('[mcp_servers."jira"]\ncommand = "old"\n\n# about features\n'
                         '[features] # trailing\nmemories = false\n')
        self.run_sync("--apply", expected=2)
        self.run_sync("--apply", "--replace-existing")
        text = codex.read_text()
        self.assertTrue(text.startswith("# about features\n[features] # trailing\n"), text)
        data = tomllib.loads(text)
        self.assertEqual(data["features"], {"memories": False})
        self.assertEqual(data["mcp_servers"]["jira"]["args"], ["https://jira.example.com"])
        self.run_sync("--check")

    def test_removing_the_only_toml_server_works(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        self.run_sync("--apply")
        self.jira_config({"work": {"url": "https://jira.example.com"}}, enabled=False)
        self.run_sync("--apply")
        self.assertEqual((self.home / ".grok/config.toml").read_text(), "")
        self.run_sync("--check")

    def test_toml_shape_sync_cannot_edit_blocks_all_writes(self):
        self.add_helper()
        self.jira_config({"work": {"url": "https://jira.example.com"}})
        codex = self.home / ".codex/config.toml"
        codex.parent.mkdir(parents=True)
        original = '[mcp_servers]\njira = { command = "inline" }\n'
        codex.write_text(original)
        result = self.run_sync("--apply", "--replace-existing", expected=2)
        self.assertEqual(codex.read_text(), original)
        self.assertFalse((self.home / ".claude.json").exists())
        self.assertFalse((self.home / ".local/bin").exists())

    def test_invalid_jira_instances_block_all_writes(self):
        (self.repo / "instructions/common.md").write_text("New instructions")
        self.jira_config({"work": {}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())
        self.jira_config({"1work": {"url": "https://jira.example.com"}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())
        self.write_config({"mcp": {"jira": {"enabled": True, "instances": []}}})
        self.run_sync("--apply", expected=2)
        self.assertFalse(self.home.exists())


if __name__ == "__main__":
    unittest.main()
