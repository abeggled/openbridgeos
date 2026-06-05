(function () {
  const apiBase = "/obos/api/v1/actions/";
  const fields = Array.from(document.querySelectorAll("[data-agent-field]"));
  const refreshButton = document.querySelector("[data-refresh-status]");
  const logsButton = document.querySelector("[data-load-logs]");
  const logOutput = document.querySelector("[data-log-output]");
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

  function setMutationStatus(statusTarget, value, state) {
    const statuses = Array.from(document.querySelectorAll(`[data-mutation-status="${statusTarget}"]`));
    for (const status of statuses) {
      status.textContent = value;
      status.dataset.state = state;
    }
  }

  async function runMutation(button) {
    const action = button.dataset.mutationAction;
    const confirmToken = button.dataset.confirm;
    const statusTarget = button.dataset.mutationStatusTarget || action;
    const backupSource = button.dataset.mutationBackupFrom;
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
