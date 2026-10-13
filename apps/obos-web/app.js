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
  const hostIdentityTlsNotice = document.querySelector("[data-host-identity-tls-notice]");
  const unsupportedActions = new Set(["restore-apply-plan"]);
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
      if (action === "tls-summary" && caDownloadLink) {
        caDownloadLink.hidden = values.trust_export_present !== "true";
      }
      for (const target of targets) {
        setField(target.element, values[target.key], "ok");
      }
    } catch (error) {
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

  async function runMutation(button) {
    const action = button.dataset.mutationAction;
    const confirmToken = button.dataset.confirm;
    const statusTarget = button.dataset.mutationStatusTarget || action;
    const backupSource = button.dataset.mutationBackupFrom;
    const portableSource = button.dataset.mutationPortableFrom;
    if (!action || !confirmToken || !window.confirm(`Confirm ${action}?`)) {
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
      if (action === "portable-export") {
        setPortableDownload(parseAgentResponse(text));
      }
      if (action === "web-auth-rotate") {
        setWebAuthPassword(parseAgentResponse(text));
      }
      if (action === "set-hostname" && hostIdentityTlsNotice) {
        hostIdentityTlsNotice.hidden = false;
      }
      const completedMessage = action === "set-hostname" ? "completed; renew leaf to apply FQDN" : "completed";
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
