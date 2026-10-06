"""Adapt the canonical Codex MCP definitions into Claude's native JSON format."""
import argparse
import json
from pathlib import Path
import tomllib


def mcp_servers(path, callback_port=None):
    data = tomllib.loads(path.read_text())
    servers = {}
    for name, server in data.get("mcp_servers", {}).items():
        if server.get("enabled", True) is False:
            continue
        # Fail on new transports instead of silently dropping configuration.
        if "url" not in server or "command" in server:
            raise ValueError(f"unsupported MCP transport for {name}")
        converted = {"type": "http", "url": server["url"]}
        oauth = {}
        if "client_id" in server.get("oauth", {}):
            oauth["clientId"] = server["oauth"]["client_id"]
            if callback_port is not None:
                oauth["callbackPort"] = callback_port
        if "scopes" in server:
            oauth["scopes"] = " ".join(server["scopes"])
        if oauth:
            converted["oauth"] = oauth
        servers[name] = converted
    return {"mcpServers": servers}


def render(base, own, output):
    output.mkdir(parents=True, exist_ok=True)
    documents = {
        "user-mcp.json": mcp_servers(base),
        "own.mcp.json": mcp_servers(
            own, tomllib.loads(base.read_text()).get("mcp_oauth_callback_port")
        ),
    }
    for name in ("default", "own", "seo", "sentry"):
        documents[f"{name}.settings.json"] = {
            "enabledPlugins": {
                "sentry@sentry-plugin-marketplace": name == "sentry",
                "claude-seo@agricidaniel-claude-seo": name == "seo",
            }
        }
    for name, document in documents.items():
        (output / name).write_text(json.dumps(document, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex-base", type=Path, required=True)
    parser.add_argument("--codex-own", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    render(args.codex_base, args.codex_own, args.output)
