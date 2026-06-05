#!/usr/bin/env python3
"""HTTP bridge for the local obos-agent."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re
import subprocess
import sys
from urllib.parse import urlparse


AGENT_PATH = os.environ.get("OBOS_AGENT_PATH", "/usr/bin/obos-agent")
BIND_HOST = os.environ.get("OBOS_AGENT_HTTP_BIND", "127.0.0.1")
BIND_PORT = int(os.environ.get("OBOS_AGENT_HTTP_PORT", "8091"))
AGENT_TIMEOUT_SECONDS = int(os.environ.get("OBOS_AGENT_HTTP_TIMEOUT_SECONDS", "45"))
AGENT_MUTATION_TIMEOUT_SECONDS = int(os.environ.get("OBOS_AGENT_HTTP_MUTATION_TIMEOUT_SECONDS", "600"))
MAX_POST_BYTES = 1024

API_PREFIX = "/obos/api/v1/actions/"
ACTION_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
READ_ONLY_ACTIONS = {
    "actions",
    "status-summary",
    "system-summary",
    "update-summary",
    "update-rollback-plan",
    "backup-summary",
    "backup-list",
    "backup-prune-plan",
    "logs-summary",
    "logs-tail",
    "restore-stage-summary",
    "mqtt-summary",
    "tls-summary",
    "security-summary",
    "agent-audit-summary",
}
MUTATING_ACTIONS = {
    "backup": "backup",
    "mqtt-disable-lan": "mqtt-disable-lan",
    "mqtt-enable-lan": "mqtt-enable-lan",
    "restart": "restart",
    "restore-stage": "restore-stage",
    "start": "start",
    "stop": "stop",
    "tls-export": "tls-export",
    "tls-generate": "tls-generate",
    "update": "update",
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

    def parse_action_path(self):
        parsed = urlparse(self.path)
        if parsed.query:
            return None, (400, error_envelope("query-not-allowed", "query strings are not accepted"))
        if not parsed.path.startswith(API_PREFIX):
            return None, (404, error_envelope("not-found", "unknown obos agent HTTP endpoint"))

        action = parsed.path[len(API_PREFIX):]
        if not action or "/" in action or not ACTION_RE.match(action):
            return None, (400, error_envelope("invalid-action", "action path segment is invalid"))
        return action, None

    def run_agent(self, args, timeout_seconds):
        return subprocess.run(
            [AGENT_PATH, *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )

    def read_confirm_body(self, action):
        content_type = self.headers.get("Content-Type", "")
        if content_type.split(";", 1)[0].strip().lower() != "application/json":
            return None, (415, error_envelope("unsupported-media-type", "POST requires application/json"))

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None, (400, error_envelope("invalid-content-length", "Content-Length is invalid"))
        if content_length <= 0:
            return None, (400, error_envelope("empty-body", "POST body is required"))
        if content_length > MAX_POST_BYTES:
            return None, (413, error_envelope("body-too-large", "POST body is too large"))

        try:
            payload = json.loads(self.rfile.read(content_length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None, (400, error_envelope("invalid-json", "POST body must be valid JSON"))

        expected_fields = {"confirm"}
        if action == "mqtt-enable-lan":
            expected_fields.add("source_cidr")
        if action == "restore-stage":
            expected_fields.add("backup_path")
        if action == "mqtt-enable-lan" and isinstance(payload, dict) and set(payload) == {"confirm"}:
            expected_fields = {"confirm"}
        if not isinstance(payload, dict) or set(payload) != expected_fields:
            return None, (400, error_envelope("invalid-body", "POST body contains unexpected fields"))
        if payload["confirm"] != MUTATING_ACTIONS[action]:
            return None, (403, error_envelope("confirmation-mismatch", "confirmation token mismatch"))
        if action == "restore-stage":
            backup_path = payload.get("backup_path")
            if not isinstance(backup_path, str) or not backup_path or backup_path.startswith("-"):
                return None, (400, error_envelope("invalid-backup-path", "backup_path is invalid"))
        if action == "mqtt-enable-lan" and "source_cidr" in payload:
            source_cidr = payload.get("source_cidr")
            if not isinstance(source_cidr, str) or not source_cidr or source_cidr.startswith("-"):
                return None, (400, error_envelope("invalid-source-cidr", "source_cidr is invalid"))
        return payload, None

    def do_GET(self):
        action, error = self.parse_action_path()
        if error:
            self.send_text(*error)
            return
        if action not in READ_ONLY_ACTIONS:
            self.send_text(404, error_envelope("unknown-action", "action is not exposed by the read-only bridge"))
            return

        try:
            completed = self.run_agent([action], AGENT_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            self.send_text(504, error_envelope("agent-timeout", "obos-agent execution timed out"))
            return
        except OSError as exc:
            self.send_text(502, error_envelope("agent-exec-failed", str(exc)))
            return

        status = 200 if completed.returncode == 0 else 502
        self.send_text(status, completed.stdout)

    def do_POST(self):
        action, error = self.parse_action_path()
        if error:
            self.send_text(*error)
            return
        if action in READ_ONLY_ACTIONS:
            self.send_text(405, error_envelope("mutations-disabled", f"HTTP mutation endpoint for {action} is not enabled"))
            return
        if action not in MUTATING_ACTIONS:
            self.send_text(404, error_envelope("unknown-action", "action is not exposed by the HTTP bridge"))
            return

        payload, body_error = self.read_confirm_body(action)
        if body_error:
            self.send_text(*body_error)
            return

        args = [action, "--confirm", payload["confirm"]]
        if action == "restore-stage":
            args = [action, payload["backup_path"], "--confirm", payload["confirm"]]
        if action == "mqtt-enable-lan" and "source_cidr" in payload:
            args = [action, payload["source_cidr"], "--confirm", payload["confirm"]]

        try:
            completed = self.run_agent(args, AGENT_MUTATION_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            self.send_text(504, error_envelope("agent-timeout", "obos-agent mutation timed out"))
            return
        except OSError as exc:
            self.send_text(502, error_envelope("agent-exec-failed", str(exc)))
            return

        status = 200 if completed.returncode == 0 else 502
        self.send_text(status, completed.stdout)

    def do_OPTIONS(self):
        self.send_text(405, error_envelope("method-not-allowed", "CORS preflight is not enabled"))


def main():
    if BIND_HOST != "127.0.0.1":
        raise SystemExit("OBOS_AGENT_HTTP_BIND must be 127.0.0.1")
    server = ThreadingHTTPServer((BIND_HOST, BIND_PORT), AgentBridgeHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
