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

# Fake curl that plays the bw serve agent. The agent is running when the
# status file exists; its content is the vault status.
FAKE_CURL = """#!/usr/bin/env python3
import json, sys, urllib.parse
from pathlib import Path

state = Path(sys.argv[0]).parent.parent / "agent"
status = state / "status"
args = sys.argv[1:]
url = next(a for a in args if a.startswith("http://"))
method = args[args.index("-X") + 1] if "-X" in args else "GET"
body = sys.stdin.read() if "@-" in args else ""
with open(state / "requests.log", "a") as log:
    log.write(json.dumps([method, url, body]) + "\\n")
if not status.exists():
    sys.exit(7)
path = url.split("localhost:8087", 1)[1]
if path == "/status":
    out = {"success": True, "data": {"template": {"status": status.read_text()}}}
elif path == "/unlock":
    ok = json.loads(body)["password"] == "master-password"
    if ok:
        status.write_text("unlocked")
    out = {"success": ok, "message": None if ok else "Invalid master password."}
else:
    items = json.loads((state / "items.json").read_text())
    key = urllib.parse.unquote(path.removeprefix("/object/item/"))
    out = {"success": True, "data": items[key]} if key in items else {
        "success": False, "message": "Not found."}
print(json.dumps(out))
"""


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / ".local/bin"
        self.runtime = self.root / "run"
        self.agent = self.root / ".local/agent"
        for path in (self.bin, self.runtime, self.agent):
            path.mkdir(parents=True)
        self.env_out = self.root / "env.json"
        self.passwords = self.root / "passwords"
        self.set_items({"https://jira.example.com": ITEM})
        self.write_cmd("curl", FAKE_CURL)
        self.write_cmd("bw", "#!/bin/sh\nexit 1\n")
        self.write_cmd("systemctl", "#!/bin/sh\nexit 0\n")
        self.write_cmd("systemd-run", f"""#!/bin/sh
echo "$@" >> '{self.agent}/systemd-run.log'
cp '{self.agent}/start-status' '{self.agent}/status'
""")
        self.write_cmd("zenity", f"""#!/bin/sh
echo zenity >> '{self.agent}/zenity.log'
[ -s '{self.passwords}' ] || exit 1
head -n 1 '{self.passwords}'
sed -i 1d '{self.passwords}'
""")
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

    def set_items(self, items):
        (self.agent / "items.json").write_text(json.dumps(items))

    def run_helper(self, expected=0, extra_env=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        env["HOME"] = str(self.root)
        env["XDG_RUNTIME_DIR"] = str(self.runtime)
        if extra_env:
            env.update(extra_env)
        result = subprocess.run([str(HELPER), "https://jira.example.com"],
                                capture_output=True, text=True, timeout=10, env=env)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def requests(self):
        log = self.agent / "requests.log"
        if not log.exists():
            return []
        return [json.loads(line) for line in log.read_text().splitlines()]

    def request_paths(self):
        return [path.removeprefix("http://localhost:8087") for _, path, _ in self.requests()]

    def zenity_calls(self):
        log = self.agent / "zenity.log"
        return len(log.read_text().splitlines()) if log.exists() else 0

    def test_unlocked_agent_needs_one_lookup_and_no_prompt(self):
        (self.agent / "status").write_text("unlocked")
        self.run_helper(extra_env={"READ_ONLY_MODE": "true"})
        self.assertEqual(self.request_paths(), [
            "/status",
            "/object/item/https%3A%2F%2Fjira.example.com",
        ])
        self.assertFalse((self.agent / "systemd-run.log").exists())
        self.assertEqual(self.zenity_calls(), 0)
        self.assertEqual(json.loads(self.env_out.read_text()), {
            "JIRA_URL": "https://jira.example.com",
            "JIRA_USERNAME": "jira-user",
            "JIRA_API_TOKEN": "jira-token",
            "READ_ONLY_MODE": None,
        })

    def test_falls_back_to_host_when_full_url_is_missing(self):
        (self.agent / "status").write_text("unlocked")
        self.set_items({"jira.example.com": ITEM})
        self.run_helper()
        self.assertEqual(self.request_paths()[1:], [
            "/object/item/https%3A%2F%2Fjira.example.com",
            "/object/item/jira.example.com",
        ])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_starts_agent_and_unlocks_with_one_prompt(self):
        (self.agent / "start-status").write_text("locked")
        self.passwords.write_text("master-password\n")
        self.run_helper()
        start = (self.agent / "systemd-run.log").read_text().split()
        self.assertIn("--unit=bw-agent", start)
        self.assertEqual(start[-3:], ["serve", "--hostname", f"unix://{self.runtime}/bw-agent.sock"])
        self.assertEqual(self.zenity_calls(), 1)
        unlocks = [body for method, path, body in self.requests() if path.endswith("/unlock")]
        self.assertEqual([json.loads(body) for body in unlocks], [{"password": "master-password"}])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_API_TOKEN"], "jira-token")

    def test_wrong_password_prompts_again(self):
        (self.agent / "status").write_text("locked")
        self.passwords.write_text("typo\nmaster-password\n")
        self.run_helper()
        self.assertEqual(self.zenity_calls(), 2)
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_not_logged_in_fails_without_prompt(self):
        (self.agent / "status").write_text("unauthenticated")
        result = self.run_helper(expected=1)
        self.assertIn("bw login", result.stderr)
        self.assertEqual(self.zenity_calls(), 0)
        self.assertFalse(self.env_out.exists())


if __name__ == "__main__":
    unittest.main()
