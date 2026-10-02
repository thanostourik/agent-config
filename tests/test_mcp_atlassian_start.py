import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
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

# Fake bw serve agent: HTTP on a unix socket. It reads its vault status from
# the status file on every request and logs each request.
FAKE_AGENT = """
import http.server, json, socketserver, sys, urllib.parse
from pathlib import Path

sock, state = sys.argv[1], Path(sys.argv[2])
status = state / "status"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.reply()

    def do_POST(self):
        self.reply()

    def reply(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0)).decode()
        with open(state / "requests.log", "a") as log:
            log.write(json.dumps([self.command, self.path, self.headers["Host"], body]) + "\\n")
        if self.path == "/status":
            out = {"success": True, "data": {"template": {"status": status.read_text()}}}
        elif self.path == "/unlock":
            ok = json.loads(body)["password"] == "master-password"
            if ok:
                status.write_text("unlocked")
            out = {"success": ok, "message": None if ok else "Invalid master password."}
        else:
            items = json.loads((state / "items.json").read_text())
            key = urllib.parse.unquote(self.path.removeprefix("/object/item/"))
            out = {"success": True, "data": items[key]} if key in items else {
                "success": False, "message": "Not found."}
        data = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


socketserver.UnixStreamServer(sock, Handler).serve_forever()
"""


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / ".local/bin"
        self.runtime = self.root / "run"
        self.state = self.root / "agent"
        for path in (self.bin, self.runtime, self.state):
            path.mkdir(parents=True)
        self.sock = self.runtime / "bw-agent.sock"
        self.env_out = self.root / "env.json"
        self.passwords = self.root / "passwords"
        self.fake_agent = self.root / "fake_agent.py"
        self.fake_agent.write_text(FAKE_AGENT)
        self.agents = []
        self.addCleanup(self.stop_agents)
        self.set_items({"https://jira.example.com": ITEM})
        self.write_cmd("bw", "#!/bin/sh\nexit 1\n")
        self.write_cmd("systemctl", "#!/bin/sh\nexit 0\n")
        self.write_cmd("systemd-run", f"""#!/bin/sh
echo "$@" >> '{self.state}/systemd-run.log'
cp '{self.state}/start-status' '{self.state}/status'
'{sys.executable}' '{self.fake_agent}' '{self.sock}' '{self.state}' >/dev/null 2>&1 &
echo $! >> '{self.state}/pids'
""")
        self.write_cmd("zenity", f"""#!/bin/sh
echo zenity >> '{self.state}/zenity.log'
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
        (self.state / "items.json").write_text(json.dumps(items))

    def start_agent(self, status):
        (self.state / "status").write_text(status)
        self.agents.append(subprocess.Popen([sys.executable, str(self.fake_agent),
                                             str(self.sock), str(self.state)]))
        deadline = time.monotonic() + 5
        while not self.sock.exists() and time.monotonic() < deadline:
            time.sleep(0.02)

    def stop_agents(self):
        for proc in self.agents:
            proc.terminate()
            proc.wait()
        pids = self.state / "pids"
        for pid in pids.read_text().split() if pids.exists() else []:
            try:
                os.kill(int(pid), signal.SIGTERM)
            except ProcessLookupError:
                pass

    def run_helper(self, expected=0, extra_env=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        env["HOME"] = str(self.root)
        env["XDG_RUNTIME_DIR"] = str(self.runtime)
        if extra_env:
            env.update(extra_env)
        result = subprocess.run([str(HELPER), "https://jira.example.com"],
                                capture_output=True, text=True, timeout=15, env=env)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def requests(self):
        log = self.state / "requests.log"
        if not log.exists():
            return []
        return [json.loads(line) for line in log.read_text().splitlines()]

    def zenity_calls(self):
        log = self.state / "zenity.log"
        return len(log.read_text().splitlines()) if log.exists() else 0

    def test_unlocked_agent_needs_one_lookup_and_no_prompt(self):
        self.start_agent("unlocked")
        self.run_helper(extra_env={"READ_ONLY_MODE": "true"})
        self.assertEqual(self.requests(), [
            ["GET", "/status", "localhost:8087", ""],
            ["GET", "/object/item/https%3A%2F%2Fjira.example.com", "localhost:8087", ""],
        ])
        self.assertFalse((self.state / "systemd-run.log").exists())
        self.assertEqual(self.zenity_calls(), 0)
        self.assertEqual(json.loads(self.env_out.read_text()), {
            "JIRA_URL": "https://jira.example.com",
            "JIRA_USERNAME": "jira-user",
            "JIRA_API_TOKEN": "jira-token",
            "READ_ONLY_MODE": None,
        })

    def test_falls_back_to_host_when_full_url_is_missing(self):
        self.start_agent("unlocked")
        self.set_items({"jira.example.com": ITEM})
        self.run_helper()
        self.assertEqual([path for _, path, _, _ in self.requests()[1:]], [
            "/object/item/https%3A%2F%2Fjira.example.com",
            "/object/item/jira.example.com",
        ])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_starts_agent_and_unlocks_with_one_prompt(self):
        (self.state / "start-status").write_text("locked")
        self.passwords.write_text("master-password\n")
        self.run_helper()
        start = (self.state / "systemd-run.log").read_text().split()
        self.assertIn("--unit=bw-agent", start)
        self.assertEqual(start[-3:], ["serve", "--hostname", f"unix://{self.sock}"])
        self.assertEqual(self.zenity_calls(), 1)
        unlocks = [body for _, path, _, body in self.requests() if path == "/unlock"]
        self.assertEqual([json.loads(body) for body in unlocks], [{"password": "master-password"}])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_API_TOKEN"], "jira-token")

    def test_wrong_password_prompts_again(self):
        self.start_agent("locked")
        self.passwords.write_text("typo\nmaster-password\n")
        self.run_helper()
        self.assertEqual(self.zenity_calls(), 2)
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_not_logged_in_fails_without_prompt(self):
        self.start_agent("unauthenticated")
        result = self.run_helper(expected=1)
        self.assertIn("bw login", result.stderr)
        self.assertEqual(self.zenity_calls(), 0)
        self.assertFalse(self.env_out.exists())


if __name__ == "__main__":
    unittest.main()
