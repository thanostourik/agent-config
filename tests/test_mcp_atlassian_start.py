import base64
import http.client
import http.server
import json
import os
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path


BIN_DIR = Path(__file__).resolve().parents[1] / "bin"
HELPER = BIN_DIR / "mcp-atlassian-start"
CRED_AGENT = BIN_DIR / "jira-cred-agent"

ITEM = {
    "login": {
        "username": "jira-user",
        "password": "jira-password",
        "uris": [{"uri": "https://jira.example.com"}],
    }
}
GATE_ITEM = {
    "login": {
        "username": "gate-user",
        "password": "gate-password",
        "uris": [{"uri": "https://jira.example.com/auth-gate"}],
    }
}

FAKE_BW = """#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

state = Path(os.environ["FAKE_BW_STATE"])
args = [a for a in sys.argv[1:] if a != "--nointeraction"]
with open(state / "bw.log", "a") as log:
    log.write(json.dumps({
        "args": args,
        "has_pw": "BW_PASSWORD" in os.environ,
        "session": os.environ.get("BW_SESSION"),
    }) + "\\n")

if args[:1] == ["status"]:
    status = (state / "status").read_text().strip()
    print(json.dumps({"status": status}))
    sys.exit(0)
if args[:1] == ["unlock"]:
    if os.environ.get("BW_PASSWORD") == "master-password":
        print("fake-session-key")
        sys.exit(0)
    print("Invalid master password.", file=sys.stderr)
    sys.exit(1)
if args[:1] == ["sync"]:
    if os.environ.get("BW_SESSION") != "fake-session-key":
        sys.exit(1)
    print("Syncing complete.")
    sys.exit(0)
if args[:2] == ["list", "items"]:
    if os.environ.get("BW_SESSION") != "fake-session-key":
        sys.exit(1)
    query = args[args.index("--url") + 1] if "--url" in args else ""
    items = json.loads((state / "items.json").read_text())
    print(json.dumps(items.get(query, [])))
    sys.exit(0)
sys.exit(1)
"""


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / ".local/bin"
        self.runtime = self.root / "run"
        self.state = self.root / "bw"
        for path in (self.bin, self.runtime, self.state):
            path.mkdir(parents=True)
        self.sock = self.runtime / "jira-cred-agent.sock"
        self.env_out = self.root / "env.json"
        self.bwrap_out = self.root / "bwrap.json"
        self.passwords = self.root / "passwords"
        self.agents = []
        self.addCleanup(self.stop_agents)
        (self.state / "status").write_text("locked")
        self.set_items({"https://jira.example.com": [ITEM]})

        self.write_cmd("bw", FAKE_BW)
        self.write_cmd("systemctl", "#!/bin/sh\nexit 0\n")
        self.write_cmd("setpriv", """#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--" ]; then
    shift
    exec "$@"
  fi
  shift
done
exit 1
""")
        self.write_cmd("systemd-run", f"""#!/bin/sh
echo "$@" >> '{self.state}/systemd-run.log'
'{sys.executable}' '{CRED_AGENT}' '{self.sock}' >/dev/null 2>&1 &
echo $! >> '{self.state}/pids'
""")
        self.write_cmd("zenity", f"""#!/bin/sh
echo zenity >> '{self.state}/zenity.log'
[ -s '{self.passwords}' ] || exit 1
head -n 1 '{self.passwords}'
sed -i 1d '{self.passwords}'
""")
        self.write_cmd("uvx", f"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
keys = ["JIRA_URL", "JIRA_USERNAME", "JIRA_API_TOKEN", "READ_ONLY_MODE", "BW_SESSION", "XDG_RUNTIME_DIR"]
data = {{k: os.environ.get(k) for k in keys}}
data["argv"] = sys.argv[1:]
Path('{self.env_out}').write_text(json.dumps(data))
if Path('{self.root / "echo_url"}').exists():
    print("issue: " + os.environ["JIRA_URL"] + "/browse/PROJ-1", flush=True)
""")
        # Fake bwrap records its arguments and executes the wrapped uvx command directly.
        self.write_cmd("bwrap", f"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
Path('{self.bwrap_out}').write_text(json.dumps(args))
os.execv(args[-2], args[-2:])
""")

    def write_cmd(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def set_items(self, items):
        (self.state / "items.json").write_text(json.dumps(items))

    def start_cred_agent(self, cached=None):
        proc = subprocess.Popen([sys.executable, str(CRED_AGENT), str(self.sock)])
        self.agents.append(proc)
        deadline = time.monotonic() + 5
        while not self.sock.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        if cached:
            conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                conn.connect(str(self.sock))
                conn.sendall((json.dumps({"op": "put", "items": cached}) + "\n").encode())
                conn.recv(4096)
            finally:
                conn.close()

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

    def run_helper(self, expected=0, extra_env=None, args=("https://jira.example.com",)):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        env["HOME"] = str(self.root)
        env["XDG_RUNTIME_DIR"] = str(self.runtime)
        env["FAKE_BW_STATE"] = str(self.state)
        if extra_env:
            env.update(extra_env)
        result = subprocess.run([str(HELPER), *args],
                                capture_output=True, text=True, timeout=15, env=env)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def bw_calls(self):
        log = self.state / "bw.log"
        if not log.exists():
            return []
        return [json.loads(line) for line in log.read_text().splitlines()]

    def zenity_calls(self):
        log = self.state / "zenity.log"
        return len(log.read_text().splitlines()) if log.exists() else 0

    def test_cached_agent_needs_no_bw_call_and_runs_sandboxed_pinned_uvx(self):
        self.start_cred_agent({
            "https://jira.example.com": {"username": "jira-user", "password": "jira-password"},
        })
        self.run_helper(extra_env={"READ_ONLY_MODE": "true"})
        self.assertEqual(self.bw_calls(), [])
        self.assertFalse((self.state / "systemd-run.log").exists())
        self.assertEqual(self.zenity_calls(), 0)
        out = json.loads(self.env_out.read_text())
        self.assertEqual(out["JIRA_URL"], "https://jira.example.com")
        self.assertEqual(out["JIRA_USERNAME"], "jira-user")
        self.assertEqual(out["JIRA_API_TOKEN"], "jira-password")
        self.assertIsNone(out["READ_ONLY_MODE"])
        self.assertIsNone(out["BW_SESSION"])
        self.assertIsNone(out["XDG_RUNTIME_DIR"])
        self.assertEqual(len(out["argv"]), 1)
        self.assertTrue(out["argv"][0].startswith("mcp-atlassian=="))
        bwrap_args = json.loads(self.bwrap_out.read_text())
        self.assertIn("--unshare-pid", bwrap_args)
        self.assertIn("--tmpfs", bwrap_args)

    def test_falls_back_to_host_when_full_url_is_missing(self):
        self.start_cred_agent()
        self.set_items({"jira.example.com": [ITEM]})
        self.passwords.write_text("master-password\n")
        self.run_helper()
        queries = [c["args"][-1] for c in self.bw_calls() if c["args"][:2] == ["list", "items"]]
        self.assertEqual(queries, ["https://jira.example.com", "jira.example.com"])
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_starts_cred_agent_and_unlocks_bw_once(self):
        self.passwords.write_text("master-password\n")
        self.run_helper()
        start = (self.state / "systemd-run.log").read_text().split()
        self.assertIn("--unit=jira-cred-agent", start)
        self.assertEqual(self.zenity_calls(), 1)
        self.assertEqual(os.stat(self.sock).st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_API_TOKEN"], "jira-password")
        # Second run hits the RAM cache without calling bw or zenity.
        self.run_helper()
        self.assertEqual(self.zenity_calls(), 1)

    def test_wrong_password_prompts_again(self):
        self.start_cred_agent()
        self.passwords.write_text("typo\nmaster-password\n")
        self.run_helper()
        self.assertEqual(self.zenity_calls(), 2)
        self.assertEqual(json.loads(self.env_out.read_text())["JIRA_USERNAME"], "jira-user")

    def test_unlock_option_caches_configured_urls_and_starts_nothing(self):
        urls_file = self.root / ".config/agent-config/jira-urls"
        urls_file.parent.mkdir(parents=True)
        urls_file.write_text("https://jira.example.com\n")
        self.passwords.write_text("master-password\n")
        self.run_helper(args=("--unlock",))
        self.assertEqual(self.zenity_calls(), 1)
        ops = [c["args"][0] for c in self.bw_calls()]
        self.assertEqual(ops, ["status", "unlock", "sync", "list"])
        self.assertFalse(self.env_out.exists())
        # Running --unlock again does not prompt because the URL is already cached.
        self.run_helper(args=("--unlock",))
        self.assertEqual(self.zenity_calls(), 1)

    def test_not_logged_in_fails_without_prompt(self):
        (self.state / "status").write_text("unauthenticated")
        result = self.run_helper(expected=1)
        self.assertIn("bw login", result.stderr)
        self.assertEqual(self.zenity_calls(), 0)
        self.assertFalse(self.env_out.exists())

    def test_gate_uses_throwaway_token_and_rewrites_urls(self):
        self.start_cred_agent({
            "https://jira.example.com": {"username": "jira-user", "password": "jira-password"},
            "https://jira.example.com/auth-gate": {
                "username": "gate-user",
                "password": "gate-password",
            },
        })
        (self.root / "echo_url").write_text("1")
        result = self.run_helper(args=("https://jira.example.com", "--gate"))
        out = json.loads(self.env_out.read_text())
        self.assertTrue(out["JIRA_URL"].startswith("http://127.0.0.1:"))
        self.assertEqual(out["JIRA_USERNAME"], "jira-user")
        self.assertNotEqual(out["JIRA_API_TOKEN"], "jira-password")
        self.assertNotEqual(out["JIRA_API_TOKEN"], "gate-password")
        self.assertGreaterEqual(len(out["JIRA_API_TOKEN"]), 32)
        self.assertIn("issue: https://jira.example.com/browse/PROJ-1", result.stdout)

    def test_gate_proxy_lazy_login_and_throwaway_token_enforcement(self):
        seen = []

        class Upstream(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(length).decode())
                seen.append(("POST", self.path, self.headers.get("Authorization"), body))
                self.send_response(200)
                self.send_header("Set-Cookie", "JSESSIONID=abc123; Path=/")
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"{}")

            def do_GET(self):
                seen.append(("GET", self.path, self.headers.get("Authorization"),
                             self.headers.get("Cookie")))
                self.send_response(200)
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"ok")

            def log_message(self, *args):
                pass

        upstream = http.server.HTTPServer(("127.0.0.1", 0), Upstream)
        thread = threading.Thread(target=upstream.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(upstream.shutdown)
        self.addCleanup(upstream.server_close)

        read_fd, write_fd = os.pipe()
        os.set_inheritable(write_fd, True)
        env = os.environ.copy()
        env.update({
            "JIRA_UPSTREAM": f"http://127.0.0.1:{upstream.server_address[1]}",
            "JIRA_GATE_USERNAME": "gate-user",
            "JIRA_GATE_PASSWORD": "gate-password",
            "JIRA_USERNAME": "jira-user",
            "JIRA_API_TOKEN": "real-jira-password",
            "JIRA_PROXY_TOKEN": "throwaway-session-token",
        })
        proxy = subprocess.Popen(
            [str(BIN_DIR / "jira-gate-proxy"), "--port-fd", str(write_fd)],
            env=env,
            pass_fds=(write_fd,),
        )
        os.close(write_fd)
        self.addCleanup(proxy.wait)
        self.addCleanup(proxy.terminate)
        port = int(os.read(read_fd, 64).decode().strip())
        os.close(read_fd)

        # Lazy login: upstream has NOT been contacted yet at startup.
        self.assertEqual(seen, [])

        # Real password is rejected by the proxy; only throwaway token is accepted.
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
        bad_auth = "Basic " + base64.b64encode(b"jira-user:real-jira-password").decode()
        conn.request("GET", "/rest/api/2/myself", headers={"Authorization": bad_auth})
        self.assertEqual(conn.getresponse().status, 401)
        conn.close()
        self.assertEqual(seen, [])

        # Throwaway token triggers lazy login with real creds and forwards with cookie.
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
        good_auth = "Basic " + base64.b64encode(b"jira-user:throwaway-session-token").decode()
        conn.request("GET", "/rest/api/2/myself", headers={"Authorization": good_auth})
        resp = conn.getresponse()
        self.assertEqual(resp.status, 200)
        self.assertEqual(resp.read(), b"ok")
        conn.close()

        expected_gate = "Basic " + base64.b64encode(b"gate-user:gate-password").decode()
        self.assertEqual(seen, [
            ("POST", "/rest/auth/1/session", expected_gate,
             {"username": "jira-user", "password": "real-jira-password"}),
            ("GET", "/rest/api/2/myself", expected_gate, "JSESSIONID=abc123"),
        ])


if __name__ == "__main__":
    unittest.main()
