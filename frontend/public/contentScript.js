/**
 * contentScript.js â€” Injected into coding platform pages.
 * Detects the current problem and notifies the background service worker.
 */
(function () {
  "use strict";
  if (window.__leettowInjected) return;
  window.__leettowInjected = true;

  const TITLE_SELECTORS = [
    '[data-cy="question-title"]',
    '.mr-2.text-label-1',
    '.text-title-large',
    'div[class*="title__"] h4',
    'h4[class*="QuestionTitle"]',
  ];

  function extractTitle() {
    for (const sel of TITLE_SELECTORS) {
      const el = document.querySelector(sel);
      if (el?.textContent?.trim()) return el.textContent.trim();
    }
    const m = document.title.match(/^(.+?)\s*[-|]/);
    return m ? m[1].trim() : null;
  }

  function extractDifficulty() {
    const el = document.querySelector(
      ".text-difficulty-easy, .text-difficulty-medium, .text-difficulty-hard"
    );
    if (!el) return "Unknown";
    const t = el.textContent.trim().toLowerCase();
    if (t.includes("easy")) return "Easy";
    if (t.includes("medium")) return "Medium";
    if (t.includes("hard")) return "Hard";
    return "Unknown";
  }

  function extractTags() {
    return Array.from(document.querySelectorAll('a[class*="topic-tag"], .topic-tag'))
      .map(el => el.textContent.trim())
      .filter(Boolean)
      .slice(0, 5);
  }

  function detectAndReport() {
    const title = extractTitle();
    if (!title) return;
    chrome.runtime.sendMessage(
      { type: "PROBLEM_DETECTED", payload: { title, difficulty: extractDifficulty(), tags: extractTags() } },
      () => void chrome.runtime.lastError
    );
  }

  let debounce = null;
  const observer = new MutationObserver((mutations) => {
    const structural = mutations.some(m => m.type === "childList" && m.addedNodes.length > 0);
    if (!structural) return;
    clearTimeout(debounce);
    debounce = setTimeout(detectAndReport, 800);
  });

  observer.observe(document.body, { childList: true, subtree: true });
  detectAndReport();
})();
