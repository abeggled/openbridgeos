(function () {
  const apiBase = "/obos/api/v1/actions/";
  const fields = Array.from(document.querySelectorAll("[data-agent-field]"));
  const refreshButton = document.querySelector("[data-refresh-status]");
  const mutationButtons = Array.from(document.querySelectorAll("[data-mutation-action]"));
  const unsupportedActions = new Set(["restore-apply-plan"]);
  const latestValues = new Map();

  function parseAgentResponse(text) {
    const values = {};
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
      if (!inStdout || !line.startsWith("stdout=")) {
        continue;
      }

      const payload = line.slice("stdout=".length);
      const separator = payload.indexOf("=");
      if (separator === -1) {
        continue;
      }
      values[payload.slice(0, separator)] = payload.slice(separator + 1);
    }

    return values;
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
