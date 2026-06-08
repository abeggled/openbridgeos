const form = document.querySelector("[data-onboarding-form]");
const statusElement = document.querySelector("[data-onboarding-status]");

function setStatus(message, state = "") {
  statusElement.textContent = message;
  if (state) {
    statusElement.dataset.state = state;
  } else {
    delete statusElement.dataset.state;
  }
}

async function checkStatus() {
  const response = await fetch("/obos/api/v1/onboarding/status", {
    cache: "no-store",
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(text.trim() || "onboarding status failed");
  }
  if (text.includes("onboarding_required=false")) {
    window.location.replace("/obos/");
    return;
  }
  setStatus("Ready to create the local admin password.");
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = new FormData(form);
  const password = String(data.get("password") || "");
  const passwordConfirm = String(data.get("password_confirm") || "");
  if (password.length < 12) {
    setStatus("Password must be at least 12 characters.", "error");
    return;
  }
  if (password !== passwordConfirm) {
    setStatus("Passwords do not match.", "error");
    return;
  }

  const button = form.querySelector("button");
  button.disabled = true;
  setStatus("Setting password...");
  try {
    const response = await fetch("/obos/api/v1/onboarding/web-auth", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ password }),
    });
    const text = await response.text();
    if (!response.ok) {
      throw new Error(text.trim() || "password setup failed");
    }
    setStatus("Password set. Opening the console...", "ok");
    window.setTimeout(() => {
      window.location.replace("/obos/");
    }, 1200);
  } catch (error) {
    setStatus(error.message, "error");
    button.disabled = false;
  }
});

checkStatus().catch((error) => {
  setStatus(error.message, "error");
});
