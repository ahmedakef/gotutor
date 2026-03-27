(function () {
  "use strict";

  const GOTUTOR_BASE = "https://gotutor.dev/?id=";
  const SHARE_URL = "https://go.dev/_/share";

  function createGoTutorButton() {
    const btn = document.createElement("button");
    btn.className = "gotutor-btn gotutor-btn-tour";
    btn.title = "Open in GoTutor";
    btn.textContent = "GoTutor";
    btn.addEventListener("click", handleClick);
    return btn;
  }

  function getCodeFromEditor() {
    const textarea = document.querySelector("#file-editor textarea");
    return textarea ? textarea.value : null;
  }

  async function handleClick(e) {
    e.preventDefault();
    const btn = e.currentTarget;
    const code = getCodeFromEditor();

    if (!code) {
      alert("Could not read code from the editor.");
      return;
    }

    btn.textContent = "Sharing…";
    btn.disabled = true;

    try {
      const resp = await fetch(SHARE_URL, {
        method: "POST",
        headers: { "Content-Type": "text/plain; charset=utf-8" },
        body: code,
      });

      if (!resp.ok) throw new Error("Share failed: " + resp.status);

      const id = await resp.text();
      window.open(GOTUTOR_BASE + id, "_blank", "noopener");
    } catch (err) {
      alert("Failed to share code: " + err.message);
    } finally {
      btn.textContent = "GoTutor";
      btn.disabled = false;
    }
  }

  function inject() {
    // Don't double-inject
    if (document.querySelector(".gotutor-btn-tour")) return;

    // Find the Run button and insert GoTutor next to it
    const runBtn = document.getElementById("run");
    if (runBtn && runBtn.parentElement) {
      runBtn.parentElement.insertBefore(createGoTutorButton(), runBtn);
      return;
    }

    // Fallback: find any button with "Run" text in the editor area
    const buttons = document.querySelectorAll("button, input[type='button']");
    for (const btn of buttons) {
      if (btn.textContent.trim() === "Run" || btn.value === "Run") {
        btn.parentElement.insertBefore(createGoTutorButton(), btn);
        return;
      }
    }
  }

  // The Go Tour is an SPA — watch for view changes and re-inject
  function observeAndInject() {
    inject();

    const target =
      document.querySelector("[ng-view]") || document.body;

    const observer = new MutationObserver(() => {
      // Re-inject if our button was removed (SPA navigation)
      if (!document.querySelector(".gotutor-btn-tour")) {
        inject();
      }
    });

    observer.observe(target, { childList: true, subtree: true });
  }

  // Wait for page to be ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", observeAndInject);
  } else {
    observeAndInject();
  }
})();
