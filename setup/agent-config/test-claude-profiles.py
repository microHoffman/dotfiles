import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parent
spec = importlib.util.spec_from_file_location("renderer", ROOT / "render-claude.py")
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)


class ClaudeProfilesTest(unittest.TestCase):
    def test_native_oauth_mapping_and_disabled_servers(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.toml"
            path.write_text('''
[mcp_servers.example]
url = "https://example.com/mcp"
scopes = ["openid", "context.read"]
default_tools_approval_mode = "writes"
[mcp_servers.example.oauth]
client_id = "public-client"
[mcp_servers.disabled]
url = "https://disabled.example.com"
enabled = false
''')
            self.assertEqual(renderer.mcp_servers(path), {"mcpServers": {
                "example": {"type": "http", "url": "https://example.com/mcp",
                            "oauth": {"clientId": "public-client",
                                      "scopes": "openid context.read"}}
            }})
            path.write_text('[mcp_servers.local]\ncommand = "unsupported"\n')
            with self.assertRaisesRegex(ValueError, "unsupported MCP transport"):
                renderer.mcp_servers(path)

    def test_profile_plugin_isolation_and_wrapper_arguments(self):
        with tempfile.TemporaryDirectory(prefix="claude profiles ") as directory:
            root = Path(directory)
            source = root / "source.toml"
            source.write_text('[mcp_servers.docs]\nurl = "https://example.com"\n')
            renderer.render(source, source, root)
            for name in ("default", "own", "seo", "sentry"):
                data = json.loads((root / f"{name}.settings.json").read_text())
                self.assertEqual(sum(data["enabledPlugins"].values()),
                                 int(name in ("seo", "sentry")))
            command = root / "claude"
            command.write_text(f"#!{shutil.which('bash')}\nprintf '%s\\0' \"$@\"\n")
            command.chmod(0o755)
            env = {**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                   "AGENT_PROFILE_CONFIG_DIR": str(root)}
            result = subprocess.run(
                ["bash", str(ROOT / "claude-profile"), "own", "--model", "opus",
                 "a prompt with spaces"], env=env, check=True, capture_output=True)
            self.assertEqual(result.stdout.decode().split("\0")[:-1], [
                "--mcp-config", str(root / "own.mcp.json"), "--settings",
                str(root / "own.settings.json"), "--model", "opus",
                "a prompt with spaces"])


if __name__ == "__main__":
    unittest.main()
