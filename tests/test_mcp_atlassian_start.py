import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "bin/mcp-atlassian-start"
ITEM = {
    "login": {
        "username": "jira-user",
        "password": "jira-token",
        "uris": [{"uri": "https://jira.example.com"}],
    }
}


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / ".local/bin"
        self.runtime = self.root / "run"
        self.bin.mkdir(parents=True)
        self.runtime.mkdir()
        self.log = self.root / "bw.log"
        self.env_out = self.root / "env.json"
        self.item = self.root / "item.json"
        self.item.write_text(json.dumps(ITEM))
        self.write_bw()
        self.write_cmd("zenity", "#!/bin/sh\necho zenity-should-not-run >&2\nexit 1\n")
        self.write_cmd("uvx", f"""#!/bin/sh
python3 -c 'import json,os,sys
keys=["JIRA_URL","JIRA_USERNAME","JIRA_API_TOKEN","READ_ONLY_MODE"]
json.dump({{k: os.environ.get(k) for k in keys}}, open(sys.argv[1], "w"))
' '{self.env_out}'
""")

    def write_cmd(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def write_bw(self):
        self.write_cmd("bw", f"""#!/bin/sh
echo "$@" >> '{self.log}'
if [ "$1" = "--nointeraction" ]; then
  shift
fi
if [ "$1" = "get" ] && [ "$2" = "item" ] && [ "$3" = "https://jira.example.com" ]; then
  cat '{self.item}'
  exit 0
fi
echo "Not found." >&2
exit 1
""")

    def run_helper(self, url="https://jira.example.com", expected=0, extra_env=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        env["HOME"] = str(self.root)
        env["XDG_RUNTIME_DIR"] = str(self.runtime)
        if extra_env:
            env.update(extra_env)
        result = subprocess.run([str(HELPER), url], capture_output=True, text=True,
                                timeout=5, env=env)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def bw_calls(self):
        if not self.log.exists():
            return []
        return [line.split() for line in self.log.read_text().splitlines() if line.strip()]

    def test_unlocked_session_uses_one_get_item_call(self):
        (self.runtime / "bw-session").write_text("session-key")
        self.run_helper(extra_env={"READ_ONLY_MODE": "true"})
        self.assertEqual(self.bw_calls(), [
            ["--nointeraction", "get", "item", "https://jira.example.com"],
        ])
        self.assertEqual(json.loads(self.env_out.read_text()), {
            "JIRA_URL": "https://jira.example.com",
            "JIRA_USERNAME": "jira-user",
            "JIRA_API_TOKEN": "jira-token",
            "READ_ONLY_MODE": None,
        })

    def test_falls_back_to_host_when_full_url_is_missing(self):
        (self.runtime / "bw-session").write_text("session-key")
        self.write_cmd("bw", f"""#!/bin/sh
echo "$@" >> '{self.log}'
if [ "$1" = "--nointeraction" ]; then
  shift
fi
if [ "$1" = "get" ] && [ "$2" = "item" ] && [ "$3" = "jira.example.com" ]; then
  cat '{self.item}'
  exit 0
fi
echo "Not found." >&2
exit 1
""")
        self.run_helper()
        self.assertEqual(self.bw_calls(), [
            ["--nointeraction", "get", "item", "https://jira.example.com"],
            ["--nointeraction", "get", "item", "jira.example.com"],
        ])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_locked_vault_unlocks_once_then_fetches(self):
        self.write_cmd("zenity", "#!/bin/sh\necho master-password\n")
        self.write_cmd("bw", f"""#!/bin/sh
echo "$@" >> '{self.log}'
if [ "$1" = "--nointeraction" ]; then
  shift
fi
if [ "$1" = "unlock" ]; then
  echo unlocked-session
  exit 0
fi
if [ ! -f '{self.runtime}/unlocked' ]; then
  echo "Vault is locked." >&2
  touch '{self.runtime}/unlocked'
  exit 1
fi
if [ "$1" = "get" ] && [ "$2" = "item" ] && [ "$3" = "https://jira.example.com" ]; then
  cat '{self.item}'
  exit 0
fi
echo "Not found." >&2
exit 1
""")
        self.run_helper()
        self.assertEqual(self.bw_calls(), [
            ["--nointeraction", "get", "item", "https://jira.example.com"],
            ["--nointeraction", "unlock", "--passwordfile",
             str(self.runtime / "bw-mp"), "--raw"],
            ["--nointeraction", "get", "item", "https://jira.example.com"],
        ])
        self.assertEqual((self.runtime / "bw-session").read_text(), "unlocked-session\n")
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_unauthenticated_does_not_prompt(self):
        self.write_cmd("bw", f"""#!/bin/sh
echo "$@" >> '{self.log}'
echo "You are not logged in." >&2
exit 1
""")
        result = self.run_helper(expected=1)
        self.assertIn("bw login", result.stderr)
        self.assertFalse(self.env_out.exists())
        self.assertEqual(self.bw_calls(), [
            ["--nointeraction", "get", "item", "https://jira.example.com"],
        ])


if __name__ == "__main__":
    unittest.main()
