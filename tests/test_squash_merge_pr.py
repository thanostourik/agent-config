import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "bin/squash-merge-pr"
REPO = "owner/repo"

# Stands in for gh. `pr view` prints pr.json; `pr merge` records its arguments,
# squashes the branch into main in the local origin, and marks the PR merged.
FAKE_GH = f"""#!{sys.executable}
import json, os, subprocess, sys
from pathlib import Path

work = Path(os.environ["FAKE_WORK"])
args = sys.argv[1:]

def git(*cmd):
    return subprocess.run(["git", "--git-dir", str(work / "origin.git"), *cmd],
                          capture_output=True, text=True, check=True).stdout.strip()

if args[:2] == ["repo", "view"]:
    print("{REPO}")
elif args[:2] == ["pr", "view"]:
    print((work / "pr.json").read_text())
elif args[:2] == ["pr", "merge"]:
    body_file = args[args.index("--body-file") + 1]
    call = {{"subject": args[args.index("--subject") + 1],
             "body": Path(body_file).read_text(),
             "match_head": args[args.index("--match-head-commit") + 1],
             "delete_branch": "--delete-branch" in args}}
    (work / "merge.json").write_text(json.dumps(call))
    pr = json.loads((work / "pr.json").read_text())
    tree = git("rev-parse", pr["headRefName"] + "^{{tree}}")
    commit = git("commit-tree", tree, "-p", "main", "-m", call["subject"] + "\\n\\n" + call["body"])
    git("update-ref", "refs/heads/main", commit)
    pr.update(state="MERGED", mergeCommit={{"oid": commit}})
    (work / "pr.json").write_text(json.dumps(pr))
else:
    sys.exit("fake gh: unexpected call " + " ".join(args))
"""

DESCRIPTION = """Why this change.

## Verification

- ran the tests

Filed by a model through a tool."""


class SquashMergePrTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.work = Path(temp.name)
        self.origin = self.work / "origin.git"
        self.clone = self.work / "clone"
        fake_bin = self.work / "bin"
        fake_bin.mkdir()
        (fake_bin / "gh").write_text(FAKE_GH)
        (fake_bin / "gh").chmod(0o755)
        self.env = {**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}",
                    "FAKE_WORK": str(self.work),
                    "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
                    "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"}
        self.git("init", "--bare", "-b", "main", str(self.origin), cwd=self.work)
        self.git("clone", str(self.origin), str(self.clone), cwd=self.work)
        self.commit("base")
        self.git("push", "origin", "main")
        self.git("switch", "-c", "feature/x")
        self.commit("work")
        self.git("push", "origin", "feature/x")
        self.write_pr()

    def git(self, *args, cwd=None):
        return subprocess.run(["git", *args], cwd=cwd or self.clone, env=self.env,
                              capture_output=True, text=True, check=True).stdout.strip()

    def commit(self, name):
        (self.clone / name).write_text(name)
        self.git("add", name)
        self.git("commit", "-m", name)

    def write_pr(self, **overrides):
        pr = {"url": f"https://github.com/{REPO}/pull/7", "number": 7, "title": "feat: thing",
              "body": DESCRIPTION, "state": "OPEN", "baseRefName": "main",
              "headRefName": "feature/x", "headRefOid": self.git("rev-parse", "HEAD"),
              "isCrossRepository": False, "isDraft": False, "mergeable": "MERGEABLE",
              "mergeStateStatus": "CLEAN", "statusCheckRollup": [], **overrides}
        (self.work / "pr.json").write_text(json.dumps(pr))

    def run_script(self):
        return subprocess.run([str(SCRIPT)], cwd=self.clone, env=self.env,
                              capture_output=True, text=True, timeout=30)

    def merge_call(self):
        return json.loads((self.work / "merge.json").read_text())

    def assert_refused(self, message):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertFalse((self.work / "merge.json").exists())
        self.assertEqual(self.git("branch", "--show-current"), "feature/x")

    def test_merges_updates_main_and_deletes_both_branches(self):
        head = self.git("rev-parse", "HEAD")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        call = self.merge_call()
        self.assertEqual(call["subject"], "feat: thing (#7)")
        self.assertEqual(call["match_head"], head)
        self.assertFalse(call["delete_branch"])
        self.assertEqual(self.git("branch", "--show-current"), "main")
        self.assertEqual(self.git("rev-parse", "main"), self.git("rev-parse", "origin/main"))
        self.assertEqual(self.git("log", "-1", "--format=%s", "main"), "feat: thing (#7)")
        self.assertEqual(self.git("branch", "--list", "feature/x"), "")
        self.assertEqual(self.git("ls-remote", "--heads", "origin", "feature/x"), "")

    def test_commit_body_drops_the_verification_section_and_keeps_filed_by(self):
        self.run_script()
        self.assertEqual(self.merge_call()["body"],
                         "Why this change.\n\nFiled by a model through a tool.\n")

    def test_commit_body_keeps_later_sections_and_skips_headings_inside_code_fences(self):
        self.write_pr(body="Intro.\n\n## Verification\n\n```sh\n# a comment\nrun\n```\n\n"
                           "## Notes\n\nKept.")
        self.run_script()
        self.assertEqual(self.merge_call()["body"], "Intro.\n\n## Notes\n\nKept.\n")

    def test_commit_body_is_unchanged_without_a_verification_section(self):
        self.write_pr(body="Intro.\n\n## Notes\n\nKept.")
        self.run_script()
        self.assertEqual(self.merge_call()["body"], "Intro.\n\n## Notes\n\nKept.\n")

    def test_refuses_with_uncommitted_work(self):
        (self.clone / "dirty").write_text("x")
        self.assert_refused("uncommitted work")

    def test_refuses_pr_that_is_a_draft_or_from_a_fork_or_not_open(self):
        for override, message in ({"isDraft": True}, "is a draft"), \
                ({"isCrossRepository": True}, "is from a fork"), \
                ({"state": "CLOSED"}, "is not open"), \
                ({"baseRefName": "dev"}, "does not target main"):
            with self.subTest(message):
                self.write_pr(**override)
                self.assert_refused(message)

    def test_refuses_when_local_branch_is_not_at_the_pr_head(self):
        self.write_pr(headRefOid="0" * 40)
        self.assert_refused("not at the PR's head commit")

    def test_refuses_when_checks_are_pending_or_failing(self):
        self.write_pr(statusCheckRollup=[
            {"name": "build", "status": "COMPLETED", "conclusion": "SUCCESS"},
            {"name": "lint", "status": "IN_PROGRESS", "conclusion": ""},
            {"context": "ci/other", "state": "FAILURE"}])
        self.assert_refused("lint")

    def test_refuses_when_merge_state_is_blocked(self):
        self.write_pr(mergeStateStatus="BLOCKED")
        self.assert_refused("cannot be merged yet")


if __name__ == "__main__":
    unittest.main()
