(function () {
  "use strict";

  const GOTUTOR_BASE = "https://gotutor.dev/?id=";
  const PLAY_URL_RE = /https?:\/\/go\.dev\/play\/p\/([A-Za-z0-9_-]+)/;

  function createGoTutorButton(playgroundId) {
    const btn = document.createElement("a");
    btn.href = GOTUTOR_BASE + playgroundId;
    btn.target = "_blank";
    btn.rel = "noopener noreferrer";
    btn.className = "gotutor-btn";
    btn.title = "Open in GoTutor";
    btn.textContent = "GoTutor";
    return btn;
  }

  function inject() {
    // Find all play links: <a href="https://go.dev/play/p/ID">
    const playLinks = document.querySelectorAll('a[href*="go.dev/play/p/"]');

    playLinks.forEach((link) => {
      // Skip if we already injected next to this link
      if (link.parentElement.querySelector(".gotutor-btn")) return;

      const match = link.href.match(PLAY_URL_RE);
      if (!match) return;

      const playgroundId = match[1];
      const btn = createGoTutorButton(playgroundId);
      // Insert before the play link so it appears next to the top-right icons
      link.parentElement.insertBefore(btn, link);
    });
  }

  inject();
})();
