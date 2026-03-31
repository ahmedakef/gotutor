document.getElementById("visualize").addEventListener("click", async () => {
  const code = document.getElementById("code").value.trim();
  const errorEl = document.getElementById("error");
  const btn = document.getElementById("visualize");

  errorEl.textContent = "";

  if (!code) {
    errorEl.textContent = "Please paste some Go code first.";
    return;
  }

  btn.textContent = "Sharing…";
  btn.disabled = true;

  try {
    const resp = await fetch("https://go.dev/_/share", {
      method: "POST",
      headers: { "Content-Type": "text/plain; charset=utf-8" },
      body: code,
    });

    if (!resp.ok) throw new Error("Server returned " + resp.status);

    const id = await resp.text();
    window.open("https://gotutor.dev/?id=" + id, "_blank");
  } catch (err) {
    errorEl.textContent = "Failed to share code: " + err.message;
  } finally {
    btn.textContent = "Visualize in GoTutor";
    btn.disabled = false;
  }
});
