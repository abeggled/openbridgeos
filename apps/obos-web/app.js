(function () {
  const apiBase = "/obos/api/v1/actions/";
  const downloadBase = "/obos/api/v1/downloads/";
  const uploadBase = "/obos/api/v1/uploads/";
  const sessionBase = "/obos/api/v1/session/";
  const sessionTimeoutMs = 10000;
  const authScreen = document.querySelector("[data-auth-screen]");
  const appShell = document.querySelector("[data-app-shell]");
  const loginForm = document.querySelector("[data-login-form]");
  const authStatus = document.querySelector("[data-auth-status]");
  const logoutButton = document.querySelector("[data-logout]");
  const fields = Array.from(document.querySelectorAll("[data-agent-field]"));
  const refreshButton = document.querySelector("[data-refresh-status]");
  const logsButton = document.querySelector("[data-load-logs]");
  const logOutput = document.querySelector("[data-log-output]");
  const securityAuditButton = document.querySelector("[data-run-security-audit]");
  const mvpReadinessButton = document.querySelector("[data-run-mvp-readiness]");
  const portableDownloadLink = document.querySelector("[data-portable-download]");
  const caDownloadLink = document.querySelector("[data-ca-download]");
  const portableUploadButton = document.querySelector("[data-upload-portable]");
  const webAuthPassword = document.querySelector("[data-web-auth-password]");
  const webAuthSecret = document.querySelector("[data-web-auth-secret]");
  const clearWebAuthPasswordButton = document.querySelector("[data-clear-web-auth-password]");
  const mutationButtons = Array.from(document.querySelectorAll("[data-mutation-action]"));
  const timezoneOptions = document.querySelector("#timezone-options");
  const helpButtons = Array.from(document.querySelectorAll("[data-help]"));
  const helpDialog = document.querySelector("[data-help-dialog]");
  const helpDialogTitle = document.querySelector("[data-help-dialog-title]");
  const helpDialogBody = document.querySelector("[data-help-dialog-body]");
  const helpCloseButton = document.querySelector("[data-help-close]");
  const confirmationDialog = document.querySelector("[data-confirm-dialog]");
  const confirmationDialogTitle = document.querySelector("[data-confirm-dialog-title]");
  const confirmationDialogBody = document.querySelector("[data-confirm-dialog-body]");
  const confirmationDialogAccept = document.querySelector("[data-confirm-dialog-accept]");
  const hostIdentityTlsNotice = document.querySelector("[data-host-identity-tls-notice]");
  const securityFailureDetails = document.querySelector("[data-security-failure-details]");
  const securityFailures = document.querySelector("[data-security-failures]");
  const mvpFailureDetails = document.querySelector("[data-mvp-failure-details]");
  const mvpFailures = document.querySelector("[data-mvp-failures]");
  const releaseNotes = document.querySelector("[data-release-notes]");
  const unsupportedActions = new Set(["restore-apply-plan"]);
  const actionConfirmations = {
    start: {
      title: "Start open bridge server?",
      body: "Starts the managed OBS container stack and makes its services available.",
      label: "Start",
      tone: "default",
    },
    stop: {
      title: "Stop open bridge server?",
      body: "Stops the managed OBS container stack. Connected clients and automations will be interrupted until it is started again.",
      label: "Stop OBS",
      tone: "danger",
    },
    restart: {
      title: "Restart open bridge server?",
      body: "Restarts the OBS container stack. Expect a short service interruption while health checks recover.",
      label: "Restart",
      tone: "warning",
    },
    update: {
      title: "Update the complete appliance?",
      body: "Checks and verifies the signed OBOS GitHub release, creates an OBS backup, updates all Debian packages (including the kernel and container runtime), pulls the configured container images, restarts OBS, and verifies health. If required, the appliance reboots automatically after a 60-second grace period. System changes are not covered by the OBS data rollback backup.",
      label: "Update Appliance",
      tone: "warning",
    },
    "set-release-channel": {
      title: "Change the update channel?",
      body: "Stable follows normal signed releases. Prerelease follows the newest signed GitHub prerelease and may contain less-tested changes.",
      label: "Apply Channel",
      tone: "warning",
    },
    backup: {
      title: "Create appliance backup?",
      body: "Creates a new local backup of OBS data, MQTT state, configuration, identity, and TLS material.",
      label: "Create Backup",
      tone: "default",
    },
    "portable-export": {
      title: "Create portable export?",
      body: "Encrypts the latest appliance backup with the supplied passphrase and prepares it for download.",
      label: "Create Export",
      tone: "default",
    },
    "restore-stage": {
      title: "Stage the latest backup?",
      body: "Extracts the latest backup into private staging for inspection. It does not change the running appliance.",
      label: "Stage Backup",
      tone: "warning",
    },
    "portable-import-stage": {
      title: "Stage the portable backup?",
      body: "Decrypts the uploaded portable backup into private staging for inspection. It does not apply the backup.",
      label: "Stage Import",
      tone: "warning",
    },
    "mqtt-enable-lan": {
      title: "Enable MQTT access from the LAN?",
      body: "Exposes the MQTT listeners beyond localhost and causes the secure-default checks to fail. Restrict the source CIDR whenever possible.",
      label: "Enable LAN Access",
      tone: "danger",
    },
    "mqtt-disable-lan": {
      title: "Return MQTT to localhost-only?",
      body: "Removes external MQTT access and restores the secure localhost-only listener policy.",
      label: "Disable LAN Access",
      tone: "default",
    },
    "set-hostname": {
      title: "Change the host identity?",
      body: "Changes the appliance hostname and optional domain. The active TLS leaf remains unchanged until Renew Leaf is selected.",
      label: "Set Host Identity",
      tone: "warning",
    },
    "set-timezone": {
      title: "Change the appliance timezone?",
      body: "Applies the selected timezone to the operating system.",
      label: "Set Timezone",
      tone: "default",
    },
    "tls-renew-leaf": {
      title: "Renew the TLS leaf certificate?",
      body: "Issues a new server certificate for the current host identity and addresses, keeps the Root CA, and reloads nginx.",
      label: "Renew Leaf",
      tone: "warning",
    },
    "web-auth-rotate": {
      title: "Rotate the console password?",
      body: "Replaces the administrator password. The new password is shown once for 60 seconds and cannot be recovered later.",
      label: "Rotate Password",
      tone: "danger",
    },
  };
  const latestValues = new Map();
  let webAuthPasswordTimer;

  function populateTimezones() {
    if (!timezoneOptions) {
      return;
    }
    const fallback = ["UTC", "Europe/Zurich", "Europe/Berlin", "Europe/London", "America/New_York", "America/Los_Angeles", "Asia/Singapore", "Asia/Tokyo", "Australia/Sydney"];
    const zones = typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : fallback;
    for (const zone of zones) {
      const option = document.createElement("option");
      option.value = zone;
      timezoneOptions.append(option);
    }
  }

  function clearWebAuthPassword() {
    if (webAuthPasswordTimer) {
      window.clearTimeout(webAuthPasswordTimer);
      webAuthPasswordTimer = undefined;
    }
    if (webAuthPassword) {
      webAuthPassword.textContent = "";
      delete webAuthPassword.dataset.state;
    }
    if (webAuthSecret) {
      webAuthSecret.hidden = true;
    }
  }

  function setAuthStatus(message, state = "") {
    if (!authStatus) {
      return;
    }
    authStatus.textContent = message;
    if (state) {
      authStatus.dataset.state = state;
    } else {
      delete authStatus.dataset.state;
    }
  }

  function showLogin(message = "Login required.", state = "") {
    clearWebAuthPassword();
    if (authScreen) {
      authScreen.hidden = false;
    }
    if (appShell) {
      appShell.hidden = true;
    }
    setAuthStatus(message, state);
  }

  function showApp() {
    if (authScreen) {
      authScreen.hidden = true;
    }
    if (appShell) {
      appShell.hidden = false;
    }
  }

  async function fetchSession(path, options = {}) {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), sessionTimeoutMs);
    try {
      return await fetch(`${sessionBase}${path}`, {
        cache: "no-store",
        credentials: "same-origin",
        ...options,
        signal: controller.signal,
      });
    } finally {
      window.clearTimeout(timeout);
    }
  }

  function agentStdoutLines(text) {
    const lines = [];
    let inStdout = false;

    for (const line of text.split(/\r?\n/)) {
      if (line === "stdout_begin") {
        inStdout = true;
        continue;
      }
      if (line === "stdout_end") {
        inStdout = false;
        continue;
      }
      if (inStdout && line.startsWith("stdout=")) {
        lines.push(line.slice("stdout=".length));
      }
    }

    return lines;
  }

  function parseAgentResponse(text) {
    const values = {};
    for (const payload of agentStdoutLines(text)) {
      const separator = payload.indexOf("=");
      if (separator === -1) {
        continue;
      }
      values[payload.slice(0, separator)] = payload.slice(separator + 1);
    }

    return values;
  }

  function parseKeyValueText(text) {
    const values = {};
    for (const line of text.split(/\r?\n/)) {
      const separator = line.indexOf("=");
      if (separator === -1) {
        continue;
      }
      values[line.slice(0, separator)] = line.slice(separator + 1);
    }
    return values;
  }

  function mutationErrorMessage(text, fallback) {
    const values = parseKeyValueText(text);
    if (values.detail) {
      return values.detail;
    }
    const stderr = text
      .split(/\r?\n/)
      .filter((line) => line.startsWith("stderr=") && line.length > "stderr=".length)
      .map((line) => line.slice("stderr=".length));
    if (stderr.length > 0) {
      return stderr.join(" | ");
    }
    return fallback;
  }

  function renderLogs(lines) {
    if (!logOutput) {
      return;
    }
    const rendered = lines
      .filter((line) => line.startsWith("log="))
      .map((line) => line.slice("log=".length))
      .join("\n");
    logOutput.textContent = rendered || "no recent log lines";
    logOutput.dataset.state = "ok";
  }

  function fieldsByAction() {
    const byAction = new Map();
    for (const field of fields) {
      const [action, key] = field.dataset.agentField.split(":");
      if (!action || !key || unsupportedActions.has(action)) {
        continue;
      }
      if (!byAction.has(action)) {
        byAction.set(action, []);
      }
      byAction.get(action).push({ element: field, key });
    }
    return byAction;
  }

  function setField(element, value, state) {
    element.textContent = value || "unknown";
    element.dataset.state = state;
  }

  function fieldState(action, key, value) {
    const normalized = String(value || "").trim().toLowerCase();
    const expectedValues = {
      "status-summary:service_active": "active",
      "status-summary:health_local": "ok",
      "status-summary:health_https_proxy": "ok",
      "system-summary:default_route_present": "true",
      "update-summary:last_update_present": "true",
      "update-summary:last_update_os_packages_updated": "true",
      "update-summary:last_update_container_images_updated": "true",
      "update-summary:last_update_reboot_pending": "false",
      "security-summary:result": "pass",
      "security-summary:fail_count": "0",
      "mvp-readiness-summary:result": "pass",
      "mvp-readiness-summary:fail_count": "0",
      "mqtt-summary:lan_enabled": "false",
      "mqtt-summary:firewall_source": "disabled",
      "tls-summary:local_ca_present": "true",
      "tls-summary:leaf_present": "true",
      "tls-summary:leaf_expiry_state": "valid",
      "tls-summary:leaf_expiry_warning": "none",
      "tls-summary:trust_export_present": "true",
      "logs-summary:raw_logs_exposed": "false",
      "logs-summary:bounded_logs_exposed": "true",
      "logs-summary:docker_present": "true",
    };
    const fieldName = `${action}:${key}`;
    if (Object.prototype.hasOwnProperty.call(expectedValues, fieldName)) {
      return normalized === expectedValues[fieldName] ? "ok" : "error";
    }
    if (action === "mqtt-summary" && ["mqtt_host_port", "mqtt_ws_host_port"].includes(key)) {
      return normalized.startsWith("127.0.0.1:") ? "ok" : "error";
    }
    if (action === "update-summary" && key === "last_update_obos_release_status") {
      return ["current", "updated"].includes(normalized) ? "ok" : "error";
    }
    if (action === "update-release-summary" && key === "release_status") {
      return ["available", "current"].includes(normalized) ? "ok" : "error";
    }
    if (["fail", "failed", "error", "unavailable", "expired", "missing", "unparseable"].includes(normalized)) {
      return "error";
    }
    if (["pass", "ok", "active", "valid", "none", "ready", "completed", "true"].includes(normalized)) {
      return "ok";
    }
    return "neutral";
  }

  function updateHostIdentityTlsNotice() {
    if (!hostIdentityTlsNotice) {
      return;
    }
    const hostname = latestValues.get("system-summary")?.hostname;
    const dnsNames = (latestValues.get("tls-summary")?.leaf_dns_names || "")
      .split(",")
      .map((value) => value.trim().toLowerCase())
      .filter(Boolean);
    if (!hostname || hostname === "unknown" || dnsNames.length === 0) {
      hostIdentityTlsNotice.hidden = true;
      return;
    }
    hostIdentityTlsNotice.hidden = dnsNames.includes(hostname.toLowerCase());
  }

  function renderFailures(container, list, values) {
    if (!container || !list) {
      return;
    }
    const failures = Object.entries(values)
      .filter(([key, value]) => /^failure_\d+$/.test(key) && value)
      .sort(([left], [right]) => Number(left.slice(8)) - Number(right.slice(8)))
      .map(([, value]) => value);
    list.replaceChildren();
    for (const failure of failures) {
      const item = document.createElement("li");
      item.textContent = failure;
      list.append(item);
    }
    container.hidden = failures.length === 0;
  }

  function releaseNoteText(values) {
    return Object.entries(values)
      .filter(([key, value]) => /^release_note_\d{3}$/.test(key) && value !== undefined)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([, value]) => value)
      .join("\n")
      .trim();
  }

  function renderReleaseNotes(values) {
    if (!releaseNotes) {
      return;
    }
    const notes = releaseNoteText(values);
    releaseNotes.textContent = notes || "No signed release notes are available.";
    releaseNotes.dataset.state = notes ? "ok" : "neutral";
  }

  async function loadAction(action, targets) {
    for (const target of targets) {
      setField(target.element, "loading", "loading");
    }

    try {
      const response = await fetch(`${apiBase}${action}`, {
        cache: "no-store",
        credentials: "same-origin",
      });
      const text = await response.text();
      if (response.status === 401) {
        showLogin();
        return;
      }
      if (!response.ok) {
        throw new Error(text || `HTTP ${response.status}`);
      }
      const values = parseAgentResponse(text);
      latestValues.set(action, values);
      updateHostIdentityTlsNotice();
      if (action === "security-summary") {
        renderFailures(securityFailureDetails, securityFailures, values);
      }
      if (action === "mvp-readiness-summary") {
        renderFailures(mvpFailureDetails, mvpFailures, values);
      }
      if (action === "update-release-summary") {
        renderReleaseNotes(values);
      }
      if (action === "release-channel-summary") {
        const releaseChannelSelect = document.querySelector("#release-channel");
        if (releaseChannelSelect && ["stable", "prerelease"].includes(values.release_channel)) {
          releaseChannelSelect.value = values.release_channel;
        }
      }
      if (action === "tls-summary" && caDownloadLink) {
        caDownloadLink.hidden = values.trust_export_present !== "true";
      }
      for (const target of targets) {
        setField(target.element, values[target.key], fieldState(action, target.key, values[target.key]));
      }
    } catch (error) {
      if (action === "security-summary") {
        renderFailures(securityFailureDetails, securityFailures, {});
      }
      if (action === "mvp-readiness-summary") {
        renderFailures(mvpFailureDetails, mvpFailures, {});
      }
      if (action === "update-release-summary") {
        renderReleaseNotes({});
      }
      for (const target of targets) {
        setField(target.element, "unavailable", "error");
      }
    }
  }

  async function refresh() {
    if (refreshButton) {
      refreshButton.disabled = true;
    }
    const grouped = fieldsByAction();
    await Promise.all(Array.from(grouped, ([action, targets]) => loadAction(action, targets)));
    if (refreshButton) {
      refreshButton.disabled = false;
    }
  }

  async function checkSession() {
    try {
      const response = await fetchSession("status");
      const text = await response.text();
      if (response.status === 401) {
        showLogin();
        return;
      }
      if (!response.ok) {
        throw new Error(text || `HTTP ${response.status}`);
      }
      const values = parseKeyValueText(text);
      if (values.authenticated === "true") {
        showApp();
        void refresh();
        return;
      }
      if (values.onboarding_required === "true") {
        window.location.replace("/obos/onboarding/");
        return;
      }
      if (values.web_auth_configured !== "true") {
        const reason = values.reason ? ` Reason: ${values.reason}.` : "";
        showLogin(`Onboarding window is not active.${reason} Reboot the appliance to set the first password.`, "error");
        return;
      }
      showLogin();
    } catch (error) {
      showLogin(error.message, "error");
    }
  }

  async function login(event) {
    event.preventDefault();
    const data = new FormData(loginForm);
    const username = String(data.get("username") || "");
    const password = String(data.get("password") || "");
    const button = loginForm.querySelector("button");
    button.disabled = true;
    setAuthStatus("Logging in...");
    try {
      const response = await fetchSession("login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ username, password }),
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(mutationErrorMessage(text, `HTTP ${response.status}`));
      }
      loginForm.reset();
      const usernameInput = loginForm.querySelector('input[name="username"]');
      if (usernameInput) {
        usernameInput.value = "admin";
      }
      showApp();
      void refresh();
    } catch (error) {
      setAuthStatus("Login failed.", "error");
    } finally {
      button.disabled = false;
    }
  }

  async function logout() {
    await fetchSession("logout", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: "{}",
    }).catch(() => {});
    showLogin("Logged out.", "ok");
  }

  if (refreshButton) {
    refreshButton.addEventListener("click", refresh);
  }

  async function refreshReadOnlyActions(button, actions) {
    if (!button) {
      return;
    }
    button.disabled = true;
    const grouped = fieldsByAction();
    await Promise.all(actions.map((action) => {
      const targets = grouped.get(action) || [];
      return targets.length > 0 ? loadAction(action, targets) : Promise.resolve();
    }));
    button.disabled = false;
  }

  async function runSecurityAudit() {
    await refreshReadOnlyActions(securityAuditButton, ["security-summary", "agent-audit-summary"]);
  }

  async function runMvpReadiness() {
    await refreshReadOnlyActions(mvpReadinessButton, ["mvp-readiness-summary"]);
  }

  if (securityAuditButton) {
    securityAuditButton.addEventListener("click", runSecurityAudit);
  }

  if (mvpReadinessButton) {
    mvpReadinessButton.addEventListener("click", runMvpReadiness);
  }

  async function loadLogs() {
    if (!logsButton || !logOutput) {
      return;
    }
    logsButton.disabled = true;
    logOutput.textContent = "loading";
    logOutput.dataset.state = "loading";
    try {
      const response = await fetch(`${apiBase}logs-tail`, {
        cache: "no-store",
        credentials: "same-origin",
      });
      const text = await response.text();
      if (response.status === 401) {
        showLogin();
        return;
      }
      if (!response.ok) {
        throw new Error(text || `HTTP ${response.status}`);
      }
      renderLogs(agentStdoutLines(text));
    } catch (error) {
      logOutput.textContent = "unavailable";
      logOutput.dataset.state = "error";
    } finally {
      logsButton.disabled = false;
    }
  }

  if (logsButton) {
    logsButton.addEventListener("click", loadLogs);
  }

  async function uploadPortableImport() {
    if (!portableUploadButton) {
      return;
    }
    const input = document.querySelector("#portable-import-file");
    const file = input?.files?.[0];
    if (!file) {
      setMutationStatus("portable-import", "missing file", "error");
      return;
    }

    portableUploadButton.disabled = true;
    setMutationStatus("portable-import", "uploading", "loading");
    try {
      const response = await fetch(`${uploadBase}portable-import`, {
        method: "POST",
        cache: "no-store",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/octet-stream",
          "X-Obos-Filename": file.name,
        },
        body: file,
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(text || `HTTP ${response.status}`);
      }
      latestValues.set("portable-import-upload", parseKeyValueText(text));
      setMutationStatus("portable-import", "uploaded", "ok");
    } catch (error) {
      setMutationStatus("portable-import", "upload failed", "error");
    } finally {
      portableUploadButton.disabled = false;
    }
  }

  if (portableUploadButton) {
    portableUploadButton.addEventListener("click", uploadPortableImport);
  }

  function setMutationStatus(statusTarget, value, state) {
    const statuses = Array.from(document.querySelectorAll(`[data-mutation-status="${statusTarget}"]`));
    for (const status of statuses) {
      status.textContent = value;
      status.dataset.state = state;
    }
  }

  function setPortableDownload(values) {
    if (!portableDownloadLink) {
      return;
    }
    const portablePath = values.portable_backup;
    if (!portablePath) {
      portableDownloadLink.hidden = true;
      portableDownloadLink.removeAttribute("href");
      return;
    }
    portableDownloadLink.href = `${downloadBase}portable-export?path=${encodeURIComponent(portablePath)}`;
    portableDownloadLink.hidden = false;
  }

  function setWebAuthPassword(values) {
    clearWebAuthPassword();
    if (!webAuthPassword || !webAuthSecret || !values.password) {
      return;
    }
    webAuthPassword.textContent = values.password;
    webAuthPassword.dataset.state = "ok";
    webAuthSecret.hidden = false;
    webAuthPasswordTimer = window.setTimeout(clearWebAuthPassword, 60000);
  }

  clearWebAuthPasswordButton?.addEventListener("click", clearWebAuthPassword);

  function confirmMutation(action) {
    if (!confirmationDialog || !confirmationDialogTitle || !confirmationDialogBody || !confirmationDialogAccept) {
      return Promise.resolve(false);
    }
    const fallbackLabel = action.split("-").map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
    const confirmation = actionConfirmations[action] || {
      title: `Continue with ${fallbackLabel}?`,
      body: "This action changes the appliance configuration or runtime state.",
      label: "Continue",
      tone: "warning",
    };
    confirmationDialogTitle.textContent = confirmation.title;
    let body = confirmation.body;
    if (action === "update") {
      const release = latestValues.get("update-release-summary") || {};
      const notes = releaseNoteText(release);
      const version = release.available_version;
      if (release.update_available === "true" && version) {
        body += `\n\nAvailable signed OBOS release: ${version}`;
        if (notes) {
          body += `\n\nRelease notes:\n${notes}`;
        }
      } else if (release.release_status === "not-configured") {
        body += "\n\nOBOS release updates are not configured because no trusted release signing key is installed.";
      }
    }
    confirmationDialogBody.textContent = body;
    confirmationDialogAccept.textContent = confirmation.label;
    confirmationDialog.dataset.tone = confirmation.tone;
    confirmationDialog.returnValue = "cancel";
    confirmationDialog.showModal();
    return new Promise((resolve) => {
      confirmationDialog.addEventListener("close", () => {
        resolve(confirmationDialog.returnValue === "confirm");
      }, { once: true });
    });
  }

  async function runMutation(button) {
    const action = button.dataset.mutationAction;
    const confirmToken = button.dataset.confirm;
    const statusTarget = button.dataset.mutationStatusTarget || action;
    const backupSource = button.dataset.mutationBackupFrom;
    const portableSource = button.dataset.mutationPortableFrom;
    if (!action || !confirmToken) {
      return;
    }

    const body = { confirm: confirmToken };
    if (backupSource) {
      const [sourceAction, sourceKey] = backupSource.split(":");
      const backupPath = latestValues.get(sourceAction)?.[sourceKey];
      if (!backupPath) {
        setMutationStatus(statusTarget, "missing backup", "error");
        return;
      }
      body.backup_path = backupPath;
    }
    if (portableSource) {
      const [sourceAction, sourceKey] = portableSource.split(":");
      const portablePath = latestValues.get(sourceAction)?.[sourceKey];
      if (!portablePath) {
        setMutationStatus(statusTarget, "missing upload", "error");
        return;
      }
      body.portable_backup = portablePath;
    }
    if (action === "mqtt-enable-lan") {
      const cidr = document.querySelector("#mqtt-source-cidr")?.value.trim();
      if (cidr) {
        body.source_cidr = cidr;
      }
    }
    if (action === "set-hostname") {
      const hostname = document.querySelector("#host-name")?.value.trim();
      const domain = document.querySelector("#host-domain")?.value.trim().replace(/^\.+|\.+$/g, "");
      if (!hostname) {
        setMutationStatus(statusTarget, "missing hostname", "error");
        return;
      }
      body.hostname = domain && !hostname.includes(".") ? `${hostname}.${domain}` : hostname;
    }
    if (action === "set-timezone") {
      const timezone = document.querySelector("#host-timezone")?.value.trim();
      if (!timezone) {
        setMutationStatus(statusTarget, "missing timezone", "error");
        return;
      }
      body.timezone = timezone;
    }
    if (action === "set-release-channel") {
      const releaseChannel = document.querySelector("#release-channel")?.value;
      if (!["stable", "prerelease"].includes(releaseChannel)) {
        setMutationStatus(statusTarget, "invalid channel", "error");
        return;
      }
      body.release_channel = releaseChannel;
    }
    if (action === "portable-export") {
      const passphrase = document.querySelector("#portable-passphrase")?.value;
      if (!passphrase) {
        setMutationStatus(statusTarget, "missing passphrase", "error");
        return;
      }
      body.passphrase = passphrase;
    }
    if (action === "portable-import-stage") {
      const passphrase = document.querySelector("#portable-import-passphrase")?.value;
      if (!passphrase) {
        setMutationStatus(statusTarget, "missing passphrase", "error");
        return;
      }
      body.passphrase = passphrase;
    }

    if (!await confirmMutation(action)) {
      return;
    }

    button.disabled = true;
    setMutationStatus(statusTarget, "running", "loading");
    try {
      const response = await fetch(`${apiBase}${action}`, {
        method: "POST",
        cache: "no-store",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      const text = await response.text();
      if (!response.ok) {
        throw new Error(mutationErrorMessage(text, `HTTP ${response.status}`));
      }
      const responseValues = parseAgentResponse(text);
      if (action === "portable-export") {
        setPortableDownload(responseValues);
      }
      if (action === "web-auth-rotate") {
        setWebAuthPassword(responseValues);
      }
      if (action === "set-hostname" && hostIdentityTlsNotice) {
        hostIdentityTlsNotice.hidden = false;
      }
      if (action === "set-release-channel") {
        latestValues.delete("update-release-summary");
      }
      let completedMessage = action === "set-hostname" ? "completed; renew leaf to apply FQDN" : "completed";
      if (action === "update" && responseValues["reboot-scheduled"] === "true") {
        completedMessage = `completed; reboot scheduled in ${responseValues["reboot-delay-seconds"] || "60"} seconds`;
      }
      setMutationStatus(statusTarget, completedMessage, "ok");
      void refresh();
    } catch (error) {
      setMutationStatus(statusTarget, error.message || "failed", "error");
    } finally {
      button.disabled = false;
    }
  }

  for (const button of mutationButtons) {
    button.addEventListener("click", () => runMutation(button));
  }

  for (const button of helpButtons) {
    button.addEventListener("click", () => {
      if (!helpDialog || !helpDialogTitle || !helpDialogBody) {
        return;
      }
      helpDialogTitle.textContent = button.dataset.helpTitle || "Help";
      helpDialogBody.textContent = button.dataset.help || "";
      helpDialog.showModal();
    });
  }

  helpCloseButton?.addEventListener("click", () => helpDialog?.close());
  helpDialog?.addEventListener("click", (event) => {
    if (event.target === helpDialog) {
      helpDialog.close();
    }
  });

  loginForm?.addEventListener("submit", login);
  logoutButton?.addEventListener("click", logout);

  populateTimezones();
  checkSession();
})();
