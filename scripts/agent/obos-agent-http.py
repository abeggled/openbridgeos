#!/usr/bin/env python3
"""Read-only HTTP bridge for the local obos-agent."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
import re
import subprocess
import sys
from urllib.parse import urlparse


AGENT_PATH = os.environ.get("OBOS_AGENT_PATH", "/usr/bin/obos-agent")
BIND_HOST = os.environ.get("OBOS_AGENT_HTTP_BIND", "127.0.0.1")
BIND_PORT = int(os.environ.get("OBOS_AGENT_HTTP_PORT", "8091"))
AGENT_TIMEOUT_SECONDS = int(os.environ.get("OBOS_AGENT_HTTP_TIMEOUT_SECONDS", "45"))

API_PREFIX = "/obos/api/v1/actions/"
ACTION_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
READ_ONLY_ACTIONS = {
    "actions",
    "status-summary",
    "update-summary",
    "backup-summary",
    "backup-prune-plan",
    "restore-stage-summary",
    "mqtt-summary",
    "tls-summary",
    "security-summary",
    "agent-audit-summary",
}


def error_envelope(error, detail):
    return (
        "format=obos-agent-http-error-v1\n"
        f"error={error}\n"
        f"detail={detail}\n"
    )


class AgentBridgeHandler(BaseHTTPRequestHandler):
    server_version = "obos-agent-http/0.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), fmt % args))

    def send_text(self, status, body):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def parse_action(self):
        parsed = urlparse(self.path)
        if parsed.query:
            return None, (400, error_envelope("query-not-allowed", "query strings are not accepted"))
        if not parsed.path.startswith(API_PREFIX):
            return None, (404, error_envelope("not-found", "unknown obos agent HTTP endpoint"))

        action = parsed.path[len(API_PREFIX):]
        if not action or "/" in action or not ACTION_RE.match(action):
            return None, (400, error_envelope("invalid-action", "action path segment is invalid"))
        if action not in READ_ONLY_ACTIONS:
            return None, (404, error_envelope("unknown-action", "action is not exposed by the read-only bridge"))
        return action, None

    def do_GET(self):
        action, error = self.parse_action()
        if error:
            self.send_text(*error)
            return

        try:
            completed = subprocess.run(
                [AGENT_PATH, action],
                check=False,
                capture_output=True,
                text=True,
                timeout=AGENT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            self.send_text(504, error_envelope("agent-timeout", "obos-agent execution timed out"))
            return
        except OSError as exc:
            self.send_text(502, error_envelope("agent-exec-failed", str(exc)))
            return

        status = 200 if completed.returncode == 0 else 502
        self.send_text(status, completed.stdout)

    def do_POST(self):
        action, error = self.parse_action()
        if error:
            self.send_text(*error)
            return
        self.send_text(
            405,
            error_envelope("mutations-disabled", f"HTTP mutation endpoint for {action} is not enabled"),
        )

    def do_OPTIONS(self):
        self.send_text(405, error_envelope("method-not-allowed", "CORS preflight is not enabled"))


def main():
    if BIND_HOST != "127.0.0.1":
        raise SystemExit("OBOS_AGENT_HTTP_BIND must be 127.0.0.1")
    server = ThreadingHTTPServer((BIND_HOST, BIND_PORT), AgentBridgeHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
