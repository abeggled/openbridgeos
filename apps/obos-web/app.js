(function () {
  const apiBase = "/obos/api/v1/actions/";
  const downloadBase = "/obos/api/v1/downloads/";
  const uploadBase = "/obos/api/v1/uploads/";
  const fields = Array.from(document.querySelectorAll("[data-agent-field]"));
  const refreshButton = document.querySelector("[data-refresh-status]");
  const logsButton = document.querySelector("[data-load-logs]");
  const logOutput = document.querySelector("[data-log-output]");
  const securityAuditButton = document.querySelector("[data-run-security-audit]");
  const mvpReadinessButton = document.querySelector("[data-run-mvp-readiness]");
  const portableDownloadLink = document.querySelector("[data-portable-download]");
  const portableUploadButton = document.querySelector("[data-upload-portable]");
  const webAuthPassword = document.querySelector("[data-web-auth-password]");
  const mutationButtons = Array.from(document.querySelectorAll("[data-mutation-action]"));
  const unsupportedActions = new Set(["restore-apply-plan"]);
  const latestValues = new Map();

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
      if (!response.ok) {
        throw new Error(text || `HTTP ${response.status}`);
      }
      const values = parseAgentResponse(text);
      latestValues.set(action, values);
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
    if (!webAuthPassword) {
      return;
    }
    webAuthPassword.textContent = values.password || "unavailable";
    webAuthPassword.dataset.state = values.password ? "ok" : "error";
  }

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
      if (!hostname) {
        setMutationStatus(statusTarget, "missing hostname", "error");
        return;
      }
      body.hostname = hostname;
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
        throw new Error(text || `HTTP ${response.status}`);
      }
      if (action === "portable-export") {
        setPortableDownload(parseAgentResponse(text));
      }
      if (action === "web-auth-rotate") {
        setWebAuthPassword(parseAgentResponse(text));
      }
      setMutationStatus(statusTarget, "completed", "ok");
      await refresh();
    } catch (error) {
      setMutationStatus(statusTarget, "failed", "error");
    } finally {
      button.disabled = false;
    }
  }

  for (const button of mutationButtons) {
    button.addEventListener("click", () => runMutation(button));
  }

  refresh();
})();
