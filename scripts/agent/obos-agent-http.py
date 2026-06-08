#!/usr/bin/env python3
"""HTTP bridge for the local obos-agent."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime
import hmac
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
from http.cookies import SimpleCookie
from urllib.parse import urlparse
from urllib.parse import parse_qs


AGENT_PATH = os.environ.get("OBOS_AGENT_PATH", "/usr/bin/obos-agent")
BIND_HOST = os.environ.get("OBOS_AGENT_HTTP_BIND", "127.0.0.1")
BIND_PORT = int(os.environ.get("OBOS_AGENT_HTTP_PORT", "8091"))
AGENT_TIMEOUT_SECONDS = int(os.environ.get("OBOS_AGENT_HTTP_TIMEOUT_SECONDS", "45"))
AGENT_MUTATION_TIMEOUT_SECONDS = int(os.environ.get("OBOS_AGENT_HTTP_MUTATION_TIMEOUT_SECONDS", "600"))
MAX_POST_BYTES = 1024
MAX_UPLOAD_BYTES = int(os.environ.get("OBOS_AGENT_HTTP_MAX_UPLOAD_BYTES", str(1024 * 1024 * 1024)))
PORTABLE_EXPORT_DIR = os.environ.get("OBOS_PORTABLE_EXPORT_DIR", "/srv/obos/state/portable-backups")
PORTABLE_IMPORT_DIR = os.environ.get("OBOS_PORTABLE_IMPORT_DIR", "/srv/obos/state/portable-imports")
ONBOARDING_STATE_DIR = os.environ.get("OBOS_ONBOARDING_STATE_DIR", "/srv/obos/state/onboarding")
ONBOARDING_REQUIRED_FILE = os.environ.get("OBOS_ONBOARDING_REQUIRED_FILE", "/srv/obos/state/onboarding/onboarding-required")
ONBOARDING_WINDOW_STATE_FILE = os.environ.get("OBOS_ONBOARDING_WINDOW_STATE_FILE", "/srv/obos/state/onboarding/window-state")
ONBOARDING_WINDOW_SECONDS = int(os.environ.get("OBOS_ONBOARDING_WINDOW_SECONDS", "300"))
WEB_AUTH_FILE = os.environ.get("OBOS_WEB_AUTH_FILE", "/etc/obos/web.htpasswd")
SESSION_DIR = os.environ.get("OBOS_SESSION_DIR", "/srv/obos/state/sessions")
SESSION_COOKIE = "obos_session"
SESSION_SECONDS = int(os.environ.get("OBOS_SESSION_SECONDS", str(8 * 60 * 60)))
SESSION_COOKIE_SECURE = os.environ.get("OBOS_SESSION_COOKIE_SECURE", "true") == "true"

API_PREFIX = "/obos/api/v1/actions/"
ONBOARDING_PREFIX = "/obos/api/v1/onboarding/"
DOWNLOAD_PREFIX = "/obos/api/v1/downloads/portable-export"
UPLOAD_PREFIX = "/obos/api/v1/uploads/portable-import"
SESSION_PREFIX = "/obos/api/v1/session/"
ACTION_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SESSION_RE = re.compile(r"^[A-Za-z0-9_-]{32,128}$")
PORTABLE_EXPORT_FILENAME_RE = re.compile(r"^obos-portable-[A-Za-z0-9T._-]+\.tar$")
PORTABLE_UPLOAD_FILENAME_RE = re.compile(r"^[A-Za-z0-9._-]+\.tar$")


def read_boot_age_seconds():
    override = os.environ.get("OBOS_ONBOARDING_BOOT_AGE_SECONDS")
    if override is not None:
        try:
            return int(override)
        except ValueError:
            return None
    try:
        with open("/proc/uptime", "r", encoding="utf-8") as handle:
            return int(float(handle.readline().split()[0]))
    except (OSError, ValueError, IndexError):
        return None


AGENT_START_BOOT_AGE_SECONDS = read_boot_age_seconds()

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
    "mvp-readiness-summary",
    "agent-audit-summary",
}
MUTATING_ACTIONS = {
    "backup": "backup",
    "mqtt-disable-lan": "mqtt-disable-lan",
    "mqtt-enable-lan": "mqtt-enable-lan",
    "portable-export": "portable-export",
    "portable-import-stage": "portable-import-stage",
    "restart": "restart",
    "restore-stage": "restore-stage",
    "set-hostname": "set-hostname",
    "set-timezone": "set-timezone",
    "start": "start",
    "stop": "stop",
    "tls-export": "tls-export",
    "tls-generate": "tls-generate",
    "update": "update",
    "web-auth-set": "web-auth-set",
    "web-auth-rotate": "web-auth-rotate",
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

    def send_text(self, status, body, headers=None):
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        if headers:
          for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(encoded)

    def send_file(self, status, path, filename):
        file_size = os.path.getsize(path)
        self.send_response(status)
        self.send_header("Content-Type", "application/x-tar")
        self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.send_header("Content-Length", str(file_size))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        with open(path, "rb") as handle:
            while True:
                chunk = handle.read(1024 * 1024)
                if not chunk:
                    break
                self.wfile.write(chunk)

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

    def read_json_body(self, allowed_fields):
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
        if isinstance(allowed_fields, list):
            allowed = any(set(payload) == fields for fields in allowed_fields) if isinstance(payload, dict) else False
        else:
            allowed = isinstance(payload, dict) and set(payload) == allowed_fields
        if not allowed:
            return None, (400, error_envelope("invalid-body", "POST body contains unexpected fields"))
        return payload, None

    def session_token(self):
        cookie_header = self.headers.get("Cookie", "")
        if not cookie_header:
            return None
        cookie = SimpleCookie()
        try:
            cookie.load(cookie_header)
        except Exception:
            return None
        morsel = cookie.get(SESSION_COOKIE)
        if not morsel:
            return None
        token = morsel.value
        if not SESSION_RE.match(token):
            return None
        return token

    def session_path(self, token):
        return os.path.join(SESSION_DIR, token)

    def cleanup_sessions(self):
        try:
            entries = os.listdir(SESSION_DIR)
        except FileNotFoundError:
            return
        now = int(time.time())
        for entry in entries:
            if not SESSION_RE.match(entry):
                continue
            path = os.path.join(SESSION_DIR, entry)
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    expires = int(handle.readline().strip())
                if expires < now:
                    os.unlink(path)
            except (OSError, ValueError):
                try:
                    os.unlink(path)
                except OSError:
                    pass

    def has_session(self):
        token = self.session_token()
        if not token:
            return False
        try:
            with open(self.session_path(token), "r", encoding="utf-8") as handle:
                expires = int(handle.readline().strip())
        except (OSError, ValueError):
            return False
        if expires < int(time.time()):
            try:
                os.unlink(self.session_path(token))
            except OSError:
                pass
            return False
        return True

    def require_session(self):
        if self.has_session():
            return True
        self.send_text(401, error_envelope("auth-required", "login required"))
        return False

    def read_web_auth_hash(self, username):
        try:
            with open(WEB_AUTH_FILE, "r", encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line or ":" not in line:
                        continue
                    candidate_user, candidate_hash = line.split(":", 1)
                    if candidate_user == username:
                        return candidate_hash
        except OSError:
            return None
        return None

    def verify_web_password(self, username, password):
        stored_hash = self.read_web_auth_hash(username)
        if not stored_hash or not stored_hash.startswith("$apr1$"):
            return False
        parts = stored_hash.split("$")
        if len(parts) < 4:
            return False
        salt = parts[2]
        try:
            completed = subprocess.run(
                ["openssl", "passwd", "-apr1", "-salt", salt, "-stdin"],
                input=f"{password}\n",
                check=False,
                capture_output=True,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            return False
        candidate_hash = completed.stdout.strip()
        return completed.returncode == 0 and hmac.compare_digest(candidate_hash, stored_hash)

    def create_session(self):
        os.makedirs(SESSION_DIR, mode=0o700, exist_ok=True)
        self.cleanup_sessions()
        token = secrets.token_urlsafe(32)
        expires = int(time.time()) + SESSION_SECONDS
        path = self.session_path(token)
        with open(path, "x", encoding="utf-8") as handle:
            handle.write(f"{expires}\n")
        os.chmod(path, 0o600)
        secure = " Secure;" if SESSION_COOKIE_SECURE else ""
        cookie = f"{SESSION_COOKIE}={token}; Path=/obos/; Max-Age={SESSION_SECONDS};{secure} HttpOnly; SameSite=Strict"
        return expires, cookie

    def clear_session(self):
        token = self.session_token()
        if token:
            try:
                os.unlink(self.session_path(token))
            except OSError:
                pass
        secure = " Secure;" if SESSION_COOKIE_SECURE else ""
        return f"{SESSION_COOKIE}=; Path=/obos/; Max-Age=0;{secure} HttpOnly; SameSite=Strict"

    def handle_session_status(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        authenticated = "true" if self.has_session() else "false"
        web_auth_configured = "true" if os.path.exists(WEB_AUTH_FILE) else "false"
        onboarding_required = "true" if self.onboarding_required() else "false"
        body = (
            "format=obos-session-status-v1\n"
            f"authenticated={authenticated}\n"
            f"web_auth_configured={web_auth_configured}\n"
            f"onboarding_required={onboarding_required}\n"
            "admin_user=admin\n"
        )
        self.send_text(200, body)

    def handle_session_login(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        payload, error = self.read_json_body({"username", "password"})
        if error:
            self.send_text(*error)
            return
        username = payload.get("username")
        password = payload.get("password")
        if not isinstance(username, str) or not isinstance(password, str):
            self.send_text(400, error_envelope("invalid-login", "username and password are required"))
            return
        if not self.verify_web_password(username, password):
            self.send_text(401, error_envelope("invalid-login", "invalid username or password"))
            return
        try:
            expires, cookie = self.create_session()
        except OSError as exc:
            self.send_text(502, error_envelope("session-create-failed", str(exc)))
            return
        body = f"format=obos-session-login-v1\nauthenticated=true\nexpires_at_epoch={expires}\n"
        self.send_text(200, body, [("Set-Cookie", cookie)])

    def handle_session_logout(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        cookie = self.clear_session()
        self.send_text(200, "format=obos-session-logout-v1\nauthenticated=false\n", [("Set-Cookie", cookie)])

    def read_confirm_body(self, action):
        expected_fields = {"confirm"}
        if action == "mqtt-enable-lan":
            expected_fields = [{"confirm"}, {"confirm", "source_cidr"}]
        if action == "portable-export":
            expected_fields.update({"backup_path", "passphrase"})
        if action == "portable-import-stage":
            expected_fields.update({"portable_backup", "passphrase"})
        if action == "restore-stage":
            expected_fields.add("backup_path")
        if action == "set-hostname":
            expected_fields.add("hostname")
        if action == "set-timezone":
            expected_fields.add("timezone")
        payload, error = self.read_json_body(expected_fields)
        if error:
            return None, error
        if payload["confirm"] != MUTATING_ACTIONS[action]:
            return None, (403, error_envelope("confirmation-mismatch", "confirmation token mismatch"))
        if action == "restore-stage":
            backup_path = payload.get("backup_path")
            if not isinstance(backup_path, str) or not backup_path or backup_path.startswith("-"):
                return None, (400, error_envelope("invalid-backup-path", "backup_path is invalid"))
        if action == "portable-export":
            backup_path = payload.get("backup_path")
            passphrase = payload.get("passphrase")
            if not isinstance(backup_path, str) or not backup_path or backup_path.startswith("-"):
                return None, (400, error_envelope("invalid-backup-path", "backup_path is invalid"))
            if not isinstance(passphrase, str) or not passphrase:
                return None, (400, error_envelope("invalid-passphrase", "passphrase is invalid"))
        if action == "portable-import-stage":
            portable_backup = payload.get("portable_backup")
            passphrase = payload.get("passphrase")
            if not isinstance(portable_backup, str) or not portable_backup or portable_backup.startswith("-"):
                return None, (400, error_envelope("invalid-portable-backup", "portable_backup is invalid"))
            if not isinstance(passphrase, str) or not passphrase:
                return None, (400, error_envelope("invalid-passphrase", "passphrase is invalid"))
        if action == "mqtt-enable-lan" and "source_cidr" in payload:
            source_cidr = payload.get("source_cidr")
            if not isinstance(source_cidr, str) or not source_cidr or source_cidr.startswith("-"):
                return None, (400, error_envelope("invalid-source-cidr", "source_cidr is invalid"))
        if action == "set-hostname":
            hostname = payload.get("hostname")
            if not isinstance(hostname, str) or not hostname or hostname.startswith("-"):
                return None, (400, error_envelope("invalid-hostname", "hostname is invalid"))
        if action == "set-timezone":
            timezone = payload.get("timezone")
            if not isinstance(timezone, str) or not timezone or timezone.startswith("-"):
                return None, (400, error_envelope("invalid-timezone", "timezone is invalid"))
        return payload, None

    def portable_download_error(self, status, error, detail):
        self.send_text(status, error_envelope(error, detail))

    def handle_portable_download(self, parsed):
        query = parse_qs(parsed.query, keep_blank_values=False)
        if set(query) != {"path"} or len(query["path"]) != 1:
            self.portable_download_error(400, "invalid-download-request", "exactly one path query parameter is required")
            return

        artifact_path = query["path"][0]
        if not artifact_path.startswith(f"{PORTABLE_EXPORT_DIR}/"):
            self.portable_download_error(403, "download-forbidden", "portable export path is outside the export directory")
            return
        if "/../" in artifact_path or artifact_path.endswith("/..") or artifact_path.startswith("../") or artifact_path == "..":
            self.portable_download_error(400, "invalid-download-path", "portable export path contains parent traversal")
            return

        filename = os.path.basename(artifact_path)
        if not PORTABLE_EXPORT_FILENAME_RE.match(filename):
            self.portable_download_error(403, "download-forbidden", "only encrypted portable export artifacts are downloadable")
            return

        export_root = os.path.realpath(PORTABLE_EXPORT_DIR)
        real_artifact = os.path.realpath(artifact_path)
        if not real_artifact.startswith(f"{export_root}{os.sep}"):
            self.portable_download_error(403, "download-forbidden", "portable export path escapes the export directory")
            return
        if not os.path.isfile(real_artifact):
            self.portable_download_error(404, "download-not-found", "portable export artifact was not found")
            return

        try:
            self.send_file(200, real_artifact, filename)
        except OSError as exc:
            self.portable_download_error(502, "download-failed", str(exc))

    def handle_portable_upload(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
        if content_type != "application/octet-stream":
            self.send_text(415, error_envelope("unsupported-media-type", "portable import upload requires application/octet-stream"))
            return
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_text(400, error_envelope("invalid-content-length", "Content-Length is invalid"))
            return
        if content_length <= 0:
            self.send_text(400, error_envelope("empty-upload", "portable import upload body is required"))
            return
        if content_length > MAX_UPLOAD_BYTES:
            self.send_text(413, error_envelope("upload-too-large", "portable import upload is too large"))
            return

        source_name = os.path.basename(self.headers.get("X-Obos-Filename", "portable-import.tar"))
        if not PORTABLE_UPLOAD_FILENAME_RE.match(source_name) or source_name.startswith("-"):
            self.send_text(400, error_envelope("invalid-upload-filename", "portable import filename is invalid"))
            return

        os.makedirs(PORTABLE_IMPORT_DIR, mode=0o700, exist_ok=True)
        uploaded_at = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        target_name = f"obos-portable-upload-{uploaded_at}-{source_name}"
        target_path = os.path.join(PORTABLE_IMPORT_DIR, target_name)
        try:
            with open(target_path, "xb") as handle:
                remaining = content_length
                while remaining > 0:
                    chunk = self.rfile.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise OSError("upload ended before Content-Length bytes were received")
                    handle.write(chunk)
                    remaining -= len(chunk)
            os.chmod(target_path, 0o600)
        except FileExistsError:
            self.send_text(409, error_envelope("upload-conflict", "portable import upload target already exists"))
            return
        except OSError as exc:
            try:
                os.unlink(target_path)
            except OSError:
                pass
            self.send_text(502, error_envelope("upload-failed", str(exc)))
            return

        body = (
            "format=obos-portable-import-upload-v1\n"
            f"portable_backup={target_path}\n"
            f"bytes_written={content_length}\n"
            "decrypt_to_private_staging=true\n"
            "live_apply_allowed=false\n"
            "portable upload: PASS\n"
        )
        self.send_text(200, body)

    def onboarding_required(self):
        status = self.onboarding_window_status()
        return status["required"]

    def onboarding_window_status(self):
        status = {
            "required": False,
            "reason": "not-required",
            "boot_id": "unknown",
            "boot_age": self.boot_age_seconds(),
            "opened_at_boot_age": None,
            "remaining": 0,
        }
        if not os.path.exists(ONBOARDING_REQUIRED_FILE) or os.path.exists(WEB_AUTH_FILE):
            if os.path.exists(WEB_AUTH_FILE):
                status["reason"] = "web-auth-configured"
            return status
        boot_age = self.boot_age_seconds()
        boot_id = self.boot_id()
        status["boot_age"] = boot_age
        status["boot_id"] = boot_id if boot_id is not None else "unknown"
        if boot_age is None or boot_id is None:
            status["reason"] = "boot-state-unavailable"
            return status

        opened_at = self.onboarding_window_opened_at(boot_id)
        if opened_at is None:
            status["reason"] = "window-state-unavailable"
            return status

        status["opened_at_boot_age"] = opened_at
        elapsed = boot_age - opened_at
        if elapsed < 0:
            elapsed = 0
        if elapsed <= ONBOARDING_WINDOW_SECONDS:
            status["required"] = True
            status["reason"] = "active"
            status["remaining"] = ONBOARDING_WINDOW_SECONDS - elapsed
        else:
            status["reason"] = "expired"
        return status

    def onboarding_window_opened_at(self, boot_id):
        values = {}
        try:
            with open(ONBOARDING_WINDOW_STATE_FILE, "r", encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if "=" in line:
                        key, value = line.split("=", 1)
                        values[key] = value
            if values.get("boot_id") == boot_id:
                return int(values.get("opened_at_boot_age", "0"))
        except (OSError, ValueError):
            pass

        opened_at = AGENT_START_BOOT_AGE_SECONDS
        if opened_at is None:
            opened_at = self.boot_age_seconds()
        if opened_at is None:
            return None

        try:
            os.makedirs(ONBOARDING_STATE_DIR, mode=0o700, exist_ok=True)
            tmp_path = f"{ONBOARDING_WINDOW_STATE_FILE}.{os.getpid()}"
            with open(tmp_path, "w", encoding="utf-8") as handle:
                handle.write("format=obos-onboarding-window-v1\n")
                handle.write(f"boot_id={boot_id}\n")
                handle.write(f"opened_at_boot_age={opened_at}\n")
                handle.write(f"window_seconds={ONBOARDING_WINDOW_SECONDS}\n")
            os.chmod(tmp_path, 0o600)
            os.replace(tmp_path, ONBOARDING_WINDOW_STATE_FILE)
        except OSError:
            return None
        return opened_at

    def boot_age_seconds(self):
        return read_boot_age_seconds()

    def boot_id(self):
        override = os.environ.get("OBOS_ONBOARDING_BOOT_ID")
        if override:
            return override
        try:
            with open("/proc/sys/kernel/random/boot_id", "r", encoding="utf-8") as handle:
                return handle.readline().strip()
        except OSError:
            return None

    def handle_onboarding_status(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        status = self.onboarding_window_status()
        required = "true" if status["required"] else "false"
        web_auth_configured = "true" if os.path.exists(WEB_AUTH_FILE) else "false"
        self.send_text(
            200,
            "format=obos-onboarding-status-v1\n"
            f"onboarding_required={required}\n"
            f"web_auth_configured={web_auth_configured}\n"
            f"window_seconds={ONBOARDING_WINDOW_SECONDS}\n"
            f"boot_id={status['boot_id']}\n"
            f"boot_age_seconds={status['boot_age'] if status['boot_age'] is not None else 'unknown'}\n"
            f"window_opened_at_boot_age={status['opened_at_boot_age'] if status['opened_at_boot_age'] is not None else 'unknown'}\n"
            f"window_remaining_seconds={status['remaining']}\n"
            f"reason={status['reason']}\n"
            "admin_user=admin\n",
        )

    def handle_onboarding_web_auth(self, parsed):
        if parsed.query:
            self.send_text(400, error_envelope("query-not-allowed", "query strings are not accepted"))
            return
        if not self.onboarding_required():
            self.send_text(410, error_envelope("onboarding-closed", "initial web onboarding is not active"))
            return

        payload, body_error = self.read_json_body({"password"})
        if body_error:
            self.send_text(*body_error)
            return
        password = payload.get("password")
        if not isinstance(password, str) or len(password) < 12:
            self.send_text(400, error_envelope("invalid-password", "password must be at least 12 characters"))
            return

        password_file = None
        try:
            os.makedirs(ONBOARDING_STATE_DIR, mode=0o700, exist_ok=True)
            handle = tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                prefix="obos-web-password-",
                dir=ONBOARDING_STATE_DIR,
                delete=False,
            )
            password_file = handle.name
            try:
                os.chmod(password_file, 0o600)
                handle.write(password)
                handle.write("\n")
            finally:
                handle.close()
            completed = self.run_agent(
                ["web-auth-set", password_file, "--confirm", "web-auth-set"],
                AGENT_MUTATION_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            self.send_text(504, error_envelope("agent-timeout", "web auth setup timed out"))
            return
        except OSError as exc:
            self.send_text(502, error_envelope("web-auth-setup-failed", str(exc)))
            return
        finally:
            if password_file:
                try:
                    os.unlink(password_file)
                except FileNotFoundError:
                    pass

        status = 200 if completed.returncode == 0 else 502
        self.send_text(status, completed.stdout)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == f"{SESSION_PREFIX}status":
            self.handle_session_status(parsed)
            return
        if parsed.path == f"{ONBOARDING_PREFIX}status":
            self.handle_onboarding_status(parsed)
            return
        if not self.require_session():
            return
        if parsed.path == DOWNLOAD_PREFIX:
            self.handle_portable_download(parsed)
            return

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
        parsed = urlparse(self.path)
        if parsed.path == f"{SESSION_PREFIX}login":
            self.handle_session_login(parsed)
            return
        if parsed.path == f"{SESSION_PREFIX}logout":
            self.handle_session_logout(parsed)
            return
        if parsed.path == f"{ONBOARDING_PREFIX}web-auth":
            self.handle_onboarding_web_auth(parsed)
            return
        if not self.require_session():
            return
        if parsed.path == UPLOAD_PREFIX:
            self.handle_portable_upload(parsed)
            return

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

        temp_passphrase_file = None
        args = [action, "--confirm", payload["confirm"]]
        if action == "portable-export":
            try:
                handle = tempfile.NamedTemporaryFile(
                    mode="w",
                    encoding="utf-8",
                    prefix="obos-agent-passphrase-",
                    dir="/tmp",
                    delete=False,
                )
                temp_passphrase_file = handle.name
                try:
                    os.chmod(temp_passphrase_file, 0o600)
                    handle.write(payload["passphrase"])
                finally:
                    handle.close()
            except OSError as exc:
                self.send_text(502, error_envelope("passphrase-file-failed", str(exc)))
                return
            args = [action, payload["backup_path"], temp_passphrase_file, "--confirm", payload["confirm"]]
        if action == "portable-import-stage":
            try:
                handle = tempfile.NamedTemporaryFile(
                    mode="w",
                    encoding="utf-8",
                    prefix="obos-agent-passphrase-",
                    dir="/tmp",
                    delete=False,
                )
                temp_passphrase_file = handle.name
                try:
                    os.chmod(temp_passphrase_file, 0o600)
                    handle.write(payload["passphrase"])
                finally:
                    handle.close()
            except OSError as exc:
                self.send_text(502, error_envelope("passphrase-file-failed", str(exc)))
                return
            args = [action, payload["portable_backup"], temp_passphrase_file, "--confirm", payload["confirm"]]
        if action == "restore-stage":
            args = [action, payload["backup_path"], "--confirm", payload["confirm"]]
        if action == "mqtt-enable-lan" and "source_cidr" in payload:
            args = [action, payload["source_cidr"], "--confirm", payload["confirm"]]
        if action == "set-hostname":
            args = [action, payload["hostname"], "--confirm", payload["confirm"]]
        if action == "set-timezone":
            args = [action, payload["timezone"], "--confirm", payload["confirm"]]

        try:
            completed = self.run_agent(args, AGENT_MUTATION_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            self.send_text(504, error_envelope("agent-timeout", "obos-agent mutation timed out"))
            return
        except OSError as exc:
            self.send_text(502, error_envelope("agent-exec-failed", str(exc)))
            return
        finally:
            if temp_passphrase_file:
                try:
                    os.unlink(temp_passphrase_file)
                except FileNotFoundError:
                    pass

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
