# LeetTow Frontend Setup Script
# Run from any directory — creates the full project at the target path.
# Usage: .\leettow_setup.ps1

$base = "C:\Users\lenovo\Documents\GitHub\leettow\frontend"

# ─── Create Folder Structure ──────────────────────────────────────────────────
$folders = @(
    "$base\public\icons",
    "$base\src\styles",
    "$base\src\hooks",
    "$base\src\utils",
    "$base\src\components\Header",
    "$base\src\components\CurrentProblem",
    "$base\src\components\HintSection",
    "$base\src\components\SimilarProblems",
    "$base\src\components\StatusBar"
)
foreach ($f in $folders) {
    New-Item -ItemType Directory -Force -Path $f | Out-Null
}
Write-Host "[1/14] Folders created." -ForegroundColor Cyan

# ─── package.json ─────────────────────────────────────────────────────────────
@'
{
  "name": "leettow",
  "version": "1.0.0",
  "description": "AI assistant Chrome Extension for coding platforms",
  "scripts": {
    "start": "react-scripts start",
    "build:ext": "cross-env INLINE_RUNTIME_CHUNK=false react-scripts build"
  },
  "dependencies": {
    "cross-env": "^7.0.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "browserslist": {
    "production": ["last 1 chrome version"],
    "development": ["last 1 chrome version"]
  }
}
'@ | Set-Content "$base\package.json" -Encoding UTF8

# ─── .gitignore ───────────────────────────────────────────────────────────────
@'
node_modules/
build/
.env
.DS_Store
'@ | Set-Content "$base\.gitignore" -Encoding UTF8

Write-Host "[2/14] package.json + .gitignore written." -ForegroundColor Cyan

# ─── public/index.html ────────────────────────────────────────────────────────
@'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>LeetTow AI Assistant</title>
  </head>
  <body>
    <noscript>JavaScript is required to run LeetTow.</noscript>
    <div id="root"></div>
  </body>
</html>
'@ | Set-Content "$base\public\index.html" -Encoding UTF8

# ─── public/manifest.json ─────────────────────────────────────────────────────
@'
{
  "manifest_version": 3,
  "name": "LeetTow AI Assistant",
  "version": "1.0.0",
  "description": "AI-powered hints and similar problems for LeetCode and coding platforms.",
  "permissions": ["activeTab", "scripting", "storage"],
  "host_permissions": [
    "https://leetcode.com/*",
    "https://www.leetcode.com/*",
    "https://hackerrank.com/*",
    "https://codeforces.com/*"
  ],
  "action": {
    "default_popup": "index.html",
    "default_title": "LeetTow AI Assistant",
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "background": {
    "service_worker": "background.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": [
        "https://leetcode.com/*",
        "https://www.leetcode.com/*",
        "https://hackerrank.com/*",
        "https://codeforces.com/*"
      ],
      "js": ["contentScript.js"],
      "run_at": "document_idle"
    }
  ],
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'"
  }
}
'@ | Set-Content "$base\public\manifest.json" -Encoding UTF8

Write-Host "[3/14] public/index.html + manifest.json written." -ForegroundColor Cyan

# ─── public/background.js ─────────────────────────────────────────────────────
@'
/**
 * background.js — Manifest V3 Service Worker
 * Central hub: caches problem data, serves hints and similar problems.
 */

const problemCache = new Map();

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.type) {

    case "PROBLEM_DETECTED": {
      if (sender.tab?.id) {
        problemCache.set(sender.tab.id, {
          title: message.payload.title,
          difficulty: message.payload.difficulty,
          tags: message.payload.tags,
          detectedAt: Date.now(),
        });
      }
      sendResponse({ success: true });
      break;
    }

    case "GET_PROBLEM_DATA": {
      chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        const activeTab = tabs[0];
        if (!activeTab?.id) {
          sendResponse({ success: false, error: "No active tab found." });
          return;
        }
        const cached = problemCache.get(activeTab.id);
        if (cached) {
          sendResponse({ success: true, data: cached });
          return;
        }
        chrome.scripting.executeScript(
          { target: { tabId: activeTab.id }, func: extractProblemFromDOM },
          (results) => {
            if (chrome.runtime.lastError || !results?.[0]?.result) {
              sendResponse({ success: false, error: "Not on a problem page." });
              return;
            }
            const data = results[0].result;
            problemCache.set(activeTab.id, data);
            sendResponse({ success: true, data });
          }
        );
      });
      return true;
    }

    case "GET_HINT": {
      const { title, hintLevel } = message.payload;
      const hint = generateMockHint(title, hintLevel);
      setTimeout(() => sendResponse({ success: true, hint }), 700);
      return true;
    }

    case "GET_SIMILAR_PROBLEMS": {
      const similar = getMockSimilarProblems(message.payload.title);
      setTimeout(() => sendResponse({ success: true, problems: similar }), 500);
      return true;
    }

    default:
      sendResponse({ success: false, error: `Unknown type: ${message.type}` });
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  problemCache.delete(tabId);
});

function extractProblemFromDOM() {
  const titleSelectors = [
    '[data-cy="question-title"]',
    '.mr-2.text-label-1',
    '.text-title-large',
    'div[class*="title__"] h4',
    'h4[class*="QuestionTitle"]',
  ];
  let title = null;
  for (const sel of titleSelectors) {
    const el = document.querySelector(sel);
    if (el?.textContent?.trim()) { title = el.textContent.trim(); break; }
  }
  if (!title) {
    const m = document.title.match(/^(.+?)\s*[-|]/);
    title = m ? m[1].trim() : null;
  }
  if (!title) return null;

  let difficulty = "Unknown";
  const diffEl = document.querySelector(
    ".text-difficulty-easy, .text-difficulty-medium, .text-difficulty-hard, [class*='difficulty']"
  );
  if (diffEl) {
    const t = diffEl.textContent.trim().toLowerCase();
    if (t.includes("easy")) difficulty = "Easy";
    else if (t.includes("medium")) difficulty = "Medium";
    else if (t.includes("hard")) difficulty = "Hard";
  }
  const tagEls = document.querySelectorAll('a[class*="topic-tag"], .topic-tag');
  const tags = Array.from(tagEls).map(el => el.textContent.trim()).filter(Boolean).slice(0, 5);
  return { title, difficulty, tags, detectedAt: Date.now() };
}

const HINTS = {
  1: "Think about the core data structure that naturally models this problem's constraints. What property must hold at every step?",
  2: "Consider how sorting or a specific traversal order might expose a pattern. Can you reduce this to a known subproblem?",
  3: "A two-pointer or sliding window approach achieves O(n). Define the invariant your window maintains, then determine when to expand or shrink.",
};

function generateMockHint(title, hintLevel = 1) {
  return HINTS[hintLevel] ?? HINTS[1];
}

function getMockSimilarProblems(title) {
  return [
    { id: 1,   number: 1,   title: "Two Sum",                                        difficulty: "Easy",   url: "https://leetcode.com/problems/two-sum/" },
    { id: 3,   number: 3,   title: "Longest Substring Without Repeating Characters", difficulty: "Medium", url: "https://leetcode.com/problems/longest-substring-without-repeating-characters/" },
    { id: 15,  number: 15,  title: "3Sum",                                           difficulty: "Medium", url: "https://leetcode.com/problems/3sum/" },
    { id: 76,  number: 76,  title: "Minimum Window Substring",                       difficulty: "Hard",   url: "https://leetcode.com/problems/minimum-window-substring/" },
    { id: 167, number: 167, title: "Two Sum II - Input Array Is Sorted",             difficulty: "Medium", url: "https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/" },
  ];
}
'@ | Set-Content "$base\public\background.js" -Encoding UTF8

Write-Host "[4/14] public/background.js written." -ForegroundColor Cyan

# ─── public/contentScript.js ──────────────────────────────────────────────────
@'
/**
 * contentScript.js — Injected into coding platform pages.
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
'@ | Set-Content "$base\public\contentScript.js" -Encoding UTF8

Write-Host "[5/14] public/contentScript.js written." -ForegroundColor Cyan

# ─── src/index.js ─────────────────────────────────────────────────────────────
@'
import React from "react";
import ReactDOM from "react-dom/client";
import "./styles/tokens.css";
import "./styles/base.css";
import App from "./App";

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@ | Set-Content "$base\src\index.js" -Encoding UTF8

# ─── src/App.js ───────────────────────────────────────────────────────────────
@'
import React from "react";
import Header from "./components/Header/Header";
import CurrentProblem from "./components/CurrentProblem/CurrentProblem";
import HintSection from "./components/HintSection/HintSection";
import SimilarProblems from "./components/SimilarProblems/SimilarProblems";
import StatusBar from "./components/StatusBar/StatusBar";
import useProblemData from "./hooks/useProblemData";
import useHint from "./hooks/useHint";
import useSimilarProblems from "./hooks/useSimilarProblems";
import "./styles/app.css";

export default function App() {
  const { problem, status, error } = useProblemData();
  const { hint, hintLevel, hintLoading, revealNextHint, resetHint } = useHint(problem?.title);
  const { problems: similarProblems, loading: similarLoading } = useSimilarProblems(problem?.title);

  return (
    <div className="app">
      <Header />
      <main className="app__main">
        <CurrentProblem problem={problem} status={status} error={error} />
        <HintSection
          hint={hint}
          hintLevel={hintLevel}
          loading={hintLoading}
          onReveal={revealNextHint}
          onReset={resetHint}
          disabled={!problem}
        />
        <SimilarProblems
          problems={similarProblems}
          loading={similarLoading}
          hasProblem={!!problem}
        />
      </main>
      <StatusBar status={status} error={error} />
    </div>
  );
}
'@ | Set-Content "$base\src\App.js" -Encoding UTF8

Write-Host "[6/14] src/index.js + App.js written." -ForegroundColor Cyan

# ─── src/utils/messaging.js ───────────────────────────────────────────────────
@'
/**
 * messaging.js — Promise wrappers around chrome.runtime.sendMessage.
 */

export function sendMessage(type, payload = {}) {
  return new Promise((resolve, reject) => {
    try {
      chrome.runtime.sendMessage({ type, payload }, (response) => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
          return;
        }
        if (!response?.success) {
          reject(new Error(response?.error ?? "Unknown error from background."));
          return;
        }
        resolve(response);
      });
    } catch (err) {
      reject(err);
    }
  });
}

export function isExtensionContext() {
  return typeof chrome !== "undefined" && !!chrome.runtime?.id;
}
'@ | Set-Content "$base\src\utils\messaging.js" -Encoding UTF8

Write-Host "[7/14] src/utils/messaging.js written." -ForegroundColor Cyan

# ─── src/hooks/useProblemData.js ──────────────────────────────────────────────
@'
import { useState, useEffect } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const DEV_MOCK_PROBLEM = {
  title: "Longest Consecutive Sequence",
  difficulty: "Medium",
  tags: ["Array", "Hash Table", "Union Find"],
  detectedAt: Date.now(),
};

export default function useProblemData() {
  const [problem, setProblem] = useState(null);
  const [status, setStatus] = useState("loading");
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchProblem() {
      setStatus("loading");
      setError(null);

      if (!isExtensionContext()) {
        setTimeout(() => {
          if (!cancelled) {
            setProblem(DEV_MOCK_PROBLEM);
            setStatus("ready");
          }
        }, 800);
        return;
      }

      try {
        const response = await sendMessage("GET_PROBLEM_DATA");
        if (!cancelled) {
          setProblem(response.data);
          setStatus("ready");
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message);
          setStatus("no-problem");
        }
      }
    }

    fetchProblem();
    return () => { cancelled = true; };
  }, []);

  return { problem, status, error };
}
'@ | Set-Content "$base\src\hooks\useProblemData.js" -Encoding UTF8

# ─── src/hooks/useHint.js ─────────────────────────────────────────────────────
@'
import { useState, useCallback, useRef } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const MAX_HINT_LEVEL = 3;

const DEV_HINTS = {
  1: "Think about the core data structure that naturally models this problem's constraints. What property must hold at every step?",
  2: "Consider how sorting or a specific traversal order might expose a pattern. Can you reduce this to a known subproblem?",
  3: "A HashSet gives you O(1) lookups. Start each streak only when the predecessor does not exist — this ensures O(n) overall.",
};

export default function useHint(problemTitle) {
  const [hint, setHint] = useState(null);
  const [hintLevel, setHintLevel] = useState(0);
  const [hintLoading, setHintLoading] = useState(false);
  const prevTitleRef = useRef(problemTitle);

  if (prevTitleRef.current !== problemTitle) {
    prevTitleRef.current = problemTitle;
  }

  const revealNextHint = useCallback(async () => {
    if (!problemTitle || hintLevel >= MAX_HINT_LEVEL) return;
    const nextLevel = hintLevel + 1;
    setHintLoading(true);
    try {
      let hintText;
      if (!isExtensionContext()) {
        await new Promise(r => setTimeout(r, 600));
        hintText = DEV_HINTS[nextLevel];
      } else {
        const response = await sendMessage("GET_HINT", { title: problemTitle, hintLevel: nextLevel });
        hintText = response.hint;
      }
      setHint(hintText);
      setHintLevel(nextLevel);
    } catch (err) {
      console.error("[LeetTow] Failed to fetch hint:", err);
    } finally {
      setHintLoading(false);
    }
  }, [problemTitle, hintLevel]);

  const resetHint = useCallback(() => {
    setHint(null);
    setHintLevel(0);
  }, []);

  return { hint, hintLevel, hintLoading, revealNextHint, resetHint, maxLevel: MAX_HINT_LEVEL };
}
'@ | Set-Content "$base\src\hooks\useHint.js" -Encoding UTF8

# ─── src/hooks/useSimilarProblems.js ──────────────────────────────────────────
@'
import { useState, useEffect } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const DEV_MOCK_SIMILAR = [
  { id: 1,   number: 1,   title: "Two Sum",                                        difficulty: "Easy",   url: "https://leetcode.com/problems/two-sum/" },
  { id: 3,   number: 3,   title: "Longest Substring Without Repeating Characters", difficulty: "Medium", url: "https://leetcode.com/problems/longest-substring-without-repeating-characters/" },
  { id: 15,  number: 15,  title: "3Sum",                                           difficulty: "Medium", url: "https://leetcode.com/problems/3sum/" },
  { id: 76,  number: 76,  title: "Minimum Window Substring",                       difficulty: "Hard",   url: "https://leetcode.com/problems/minimum-window-substring/" },
  { id: 167, number: 167, title: "Two Sum II - Input Array Is Sorted",             difficulty: "Medium", url: "https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/" },
];

export default function useSimilarProblems(problemTitle) {
  const [problems, setProblems] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!problemTitle) return;
    let cancelled = false;
    setLoading(true);

    async function fetch() {
      try {
        let result;
        if (!isExtensionContext()) {
          await new Promise(r => setTimeout(r, 600));
          result = DEV_MOCK_SIMILAR;
        } else {
          const response = await sendMessage("GET_SIMILAR_PROBLEMS", { title: problemTitle });
          result = response.problems;
        }
        if (!cancelled) setProblems(result);
      } catch (err) {
        console.error("[LeetTow] Failed to fetch similar problems:", err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetch();
    return () => { cancelled = true; };
  }, [problemTitle]);

  return { problems, loading };
}
'@ | Set-Content "$base\src\hooks\useSimilarProblems.js" -Encoding UTF8

Write-Host "[8/14] All hooks written." -ForegroundColor Cyan

# ─── src/styles/tokens.css ────────────────────────────────────────────────────
@'
:root {
  --color-bg:               #0d1117;
  --color-surface:          #161b22;
  --color-surface-2:        #1c2128;
  --color-surface-offset:   #21262d;
  --color-surface-dynamic:  #30363d;
  --color-border:           #30363d;
  --color-divider:          #21262d;

  --color-text:             #e6edf3;
  --color-text-muted:       #8b949e;
  --color-text-faint:       #484f58;
  --color-text-inverse:     #0d1117;

  --color-primary:          #00b4d8;
  --color-primary-hover:    #0096c7;
  --color-primary-active:   #0077b6;
  --color-primary-dim:      rgba(0, 180, 216, 0.12);
  --color-primary-glow:     rgba(0, 180, 216, 0.2);

  --color-easy:             #3fb950;
  --color-medium:           #d29922;
  --color-hard:             #f85149;

  --color-success:          #3fb950;
  --color-warning:          #d29922;
  --color-error:            #f85149;

  --radius-sm:   4px;
  --radius-md:   6px;
  --radius-lg:   10px;
  --radius-xl:   14px;
  --radius-full: 9999px;

  --space-1:  4px;
  --space-2:  8px;
  --space-3:  12px;
  --space-4:  16px;
  --space-5:  20px;
  --space-6:  24px;
  --space-8:  32px;
  --space-10: 40px;

  --text-xs:   11px;
  --text-sm:   12px;
  --text-base: 13px;
  --text-md:   14px;
  --text-lg:   16px;
  --text-xl:   18px;

  --font-ui:   -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  --font-mono: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;

  --shadow-sm: 0 1px 3px rgba(0,0,0,0.4);
  --shadow-md: 0 4px 12px rgba(0,0,0,0.5);

  --transition: 150ms cubic-bezier(0.16, 1, 0.3, 1);

  --popup-width:  360px;
  --popup-height: 560px;
}
'@ | Set-Content "$base\src\styles\tokens.css" -Encoding UTF8

# ─── src/styles/base.css ──────────────────────────────────────────────────────
@'
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html, body, #root {
  width: var(--popup-width);
  height: var(--popup-height);
  overflow: hidden;
}

body {
  font-family: var(--font-ui);
  font-size: var(--text-base);
  color: var(--color-text);
  background-color: var(--color-bg);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

button { cursor: pointer; background: none; border: none; font: inherit; color: inherit; }
a { color: var(--color-primary); text-decoration: none; }
a:hover { text-decoration: underline; color: var(--color-primary-hover); }
ul { list-style: none; }

:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}

::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-track { background: var(--color-surface); }
::-webkit-scrollbar-thumb { background: var(--color-surface-dynamic); border-radius: var(--radius-full); }
::-webkit-scrollbar-thumb:hover { background: var(--color-text-faint); }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
'@ | Set-Content "$base\src\styles\base.css" -Encoding UTF8

# ─── src/styles/app.css ───────────────────────────────────────────────────────
@'
.app {
  display: flex;
  flex-direction: column;
  width: var(--popup-width);
  height: var(--popup-height);
  background: var(--color-bg);
  overflow: hidden;
}

.app__main {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: var(--space-3) var(--space-4);
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.section-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-3) var(--space-4);
}

.section-title {
  font-size: var(--text-sm);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-text-muted);
  margin-bottom: var(--space-2);
}
'@ | Set-Content "$base\src\styles\app.css" -Encoding UTF8

Write-Host "[9/14] All CSS files written." -ForegroundColor Cyan

# ─── Header Component ─────────────────────────────────────────────────────────
@'
import React from "react";
import "./Header.css";

export default function Header() {
  return (
    <header className="header">
      <div className="header__logo" aria-hidden="true">
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none" aria-hidden="true">
          <rect width="22" height="22" rx="5" fill="#00b4d8" />
          <path d="M5 6h4v7h4v3H5V6z" fill="#0d1117" />
          <path d="M14 6h3v4h-1.5v6H14V6z" fill="#0d1117" />
        </svg>
      </div>
      <div className="header__text">
        <h1 className="header__title">LeetTow</h1>
        <span className="header__subtitle">AI Assistant</span>
      </div>
      <div className="header__badge">AI</div>
    </header>
  );
}
'@ | Set-Content "$base\src\components\Header\Header.js" -Encoding UTF8

@'
.header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-4);
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  flex-shrink: 0;
}
.header__logo { flex-shrink: 0; }
.header__text { flex: 1; display: flex; align-items: baseline; gap: var(--space-2); }
.header__title { font-size: var(--text-lg); font-weight: 700; color: var(--color-text); letter-spacing: -0.02em; }
.header__subtitle { font-size: var(--text-xs); color: var(--color-text-muted); font-weight: 400; }
.header__badge {
  font-size: var(--text-xs); font-weight: 700;
  color: var(--color-primary);
  background: var(--color-primary-dim);
  border: 1px solid rgba(0, 180, 216, 0.25);
  border-radius: var(--radius-full);
  padding: 2px var(--space-2);
  letter-spacing: 0.04em;
}
'@ | Set-Content "$base\src\components\Header\Header.css" -Encoding UTF8

Write-Host "[10/14] Header component written." -ForegroundColor Cyan

# ─── CurrentProblem Component ─────────────────────────────────────────────────
@'
import React from "react";
import "./CurrentProblem.css";

const DIFFICULTY_MAP = {
  Easy:    { label: "Easy",   cls: "difficulty--easy"   },
  Medium:  { label: "Medium", cls: "difficulty--medium" },
  Hard:    { label: "Hard",   cls: "difficulty--hard"   },
  Unknown: { label: "-",      cls: ""                   },
};

export default function CurrentProblem({ problem, status, error }) {
  const diff = DIFFICULTY_MAP[problem?.difficulty] ?? DIFFICULTY_MAP["Unknown"];

  return (
    <section className="section-card current-problem" aria-label="Current problem">
      <p className="section-title">Current Problem</p>

      {status === "loading" && (
        <div className="current-problem__skeleton" aria-busy="true" aria-label="Loading problem">
          <div className="skeleton skeleton--title" />
          <div className="skeleton skeleton--tags" />
        </div>
      )}

      {status === "no-problem" && (
        <div className="current-problem__empty">
          <p className="current-problem__empty-text">
            {error ?? "Open a problem on LeetCode to get started."}
          </p>
        </div>
      )}

      {status === "ready" && problem && (
        <div className="current-problem__content">
          <div className="current-problem__row">
            <h2 className="current-problem__title">{problem.title}</h2>
            <span className={`difficulty-badge ${diff.cls}`}>{diff.label}</span>
          </div>
          {problem.tags?.length > 0 && (
            <ul className="current-problem__tags" aria-label="Topic tags">
              {problem.tags.map((tag) => (
                <li key={tag} className="tag">{tag}</li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
'@ | Set-Content "$base\src\components\CurrentProblem\CurrentProblem.js" -Encoding UTF8

@'
.current-problem__row { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--space-2); }
.current-problem__title { font-size: var(--text-md); font-weight: 600; color: var(--color-text); line-height: 1.4; flex: 1; }
.difficulty-badge { font-size: var(--text-xs); font-weight: 600; padding: 2px var(--space-2); border-radius: var(--radius-full); white-space: nowrap; flex-shrink: 0; }
.difficulty--easy   { color: var(--color-easy);   background: rgba(63,185,80,0.12);  }
.difficulty--medium { color: var(--color-medium); background: rgba(210,153,34,0.12); }
.difficulty--hard   { color: var(--color-hard);   background: rgba(248,81,73,0.12);  }
.current-problem__tags { display: flex; flex-wrap: wrap; gap: var(--space-1); margin-top: var(--space-2); }
.tag { font-size: var(--text-xs); color: var(--color-text-muted); background: var(--color-surface-offset); border: 1px solid var(--color-border); border-radius: var(--radius-full); padding: 1px var(--space-2); }
.current-problem__skeleton { display: flex; flex-direction: column; gap: var(--space-2); }
@keyframes shimmer { 0% { background-position: -200% 0; } 100% { background-position: 200% 0; } }
.skeleton { background: linear-gradient(90deg, var(--color-surface-offset) 25%, var(--color-surface-dynamic) 50%, var(--color-surface-offset) 75%); background-size: 200% 100%; animation: shimmer 1.5s ease-in-out infinite; border-radius: var(--radius-sm); }
.skeleton--title { height: 18px; width: 75%; }
.skeleton--tags  { height: 12px; width: 50%; margin-top: var(--space-1); }
.current-problem__empty-text { font-size: var(--text-sm); color: var(--color-text-muted); line-height: 1.5; }
'@ | Set-Content "$base\src\components\CurrentProblem\CurrentProblem.css" -Encoding UTF8

Write-Host "[11/14] CurrentProblem component written." -ForegroundColor Cyan

# ─── HintSection Component ────────────────────────────────────────────────────
@'
import React from "react";
import "./HintSection.css";

const MAX_LEVEL = 3;
const LEVEL_LABELS = { 0: null, 1: "Vague Nudge", 2: "Directional", 3: "Algorithmic" };

export default function HintSection({ hint, hintLevel, loading, onReveal, onReset, disabled }) {
  const atMax = hintLevel >= MAX_LEVEL;
  const hasHint = hintLevel > 0 && hint;

  return (
    <section className="section-card hint-section" aria-label="AI hint">
      <div className="hint-section__header">
        <p className="section-title">AI Hint</p>
        {hintLevel > 0 && (
          <span className="hint-level-badge">Level {hintLevel} — {LEVEL_LABELS[hintLevel]}</span>
        )}
      </div>

      {hasHint && (
        <div className="hint-section__content" role="status" aria-live="polite">
          <p className="hint-text">{hint}</p>
          <div className="hint-dots" aria-label={`Hint level ${hintLevel} of ${MAX_LEVEL}`}>
            {Array.from({ length: MAX_LEVEL }, (_, i) => (
              <span key={i} className={`hint-dot ${i < hintLevel ? "hint-dot--active" : ""}`} />
            ))}
          </div>
        </div>
      )}

      {!hasHint && !loading && (
        <p className="hint-section__placeholder">
          {disabled ? "Hints unlock once a problem is detected." : "Hints are revealed progressively — no spoilers."}
        </p>
      )}

      {loading && (
        <div className="hint-section__loading" aria-busy="true">
          <span className="spinner" aria-hidden="true" />
          <span className="hint-section__loading-text">Thinking...</span>
        </div>
      )}

      <div className="hint-section__actions">
        <button
          className="btn btn--primary"
          onClick={onReveal}
          disabled={disabled || loading || atMax}
          aria-label={hintLevel === 0 ? "Show first hint" : "Show next hint level"}
        >
          {atMax ? "Max hints reached" : hintLevel === 0 ? "Show Hint" : "Next Hint"}
        </button>
        {hintLevel > 0 && (
          <button className="btn btn--ghost" onClick={onReset} disabled={loading} aria-label="Reset hints">
            Reset
          </button>
        )}
      </div>
    </section>
  );
}
'@ | Set-Content "$base\src\components\HintSection\HintSection.js" -Encoding UTF8

@'
.hint-section__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--space-2); }
.hint-section__header .section-title { margin-bottom: 0; }
.hint-level-badge { font-size: var(--text-xs); font-weight: 600; color: var(--color-primary); background: var(--color-primary-dim); border-radius: var(--radius-full); padding: 2px var(--space-2); }
.hint-section__content { margin-bottom: var(--space-3); }
.hint-text { font-size: var(--text-base); color: var(--color-text); line-height: 1.65; border-left: 2px solid var(--color-primary); padding-left: var(--space-3); animation: fadeSlideIn 0.25s ease forwards; }
@keyframes fadeSlideIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }
.hint-dots { display: flex; gap: var(--space-1); margin-top: var(--space-3); }
.hint-dot { width: 6px; height: 6px; border-radius: var(--radius-full); background: var(--color-surface-dynamic); transition: background var(--transition); }
.hint-dot--active { background: var(--color-primary); }
.hint-section__placeholder { font-size: var(--text-sm); color: var(--color-text-muted); margin-bottom: var(--space-3); line-height: 1.5; }
.hint-section__loading { display: flex; align-items: center; gap: var(--space-2); margin-bottom: var(--space-3); }
.hint-section__loading-text { font-size: var(--text-sm); color: var(--color-text-muted); }
@keyframes spin { to { transform: rotate(360deg); } }
.spinner { display: inline-block; width: 14px; height: 14px; border: 2px solid var(--color-surface-dynamic); border-top-color: var(--color-primary); border-radius: var(--radius-full); animation: spin 0.7s linear infinite; flex-shrink: 0; }
.hint-section__actions { display: flex; gap: var(--space-2); }
.btn { display: inline-flex; align-items: center; justify-content: center; height: 32px; padding: 0 var(--space-4); border-radius: var(--radius-md); font-size: var(--text-sm); font-weight: 600; cursor: pointer; transition: background var(--transition), color var(--transition), border-color var(--transition); white-space: nowrap; border: 1px solid transparent; }
.btn:disabled { opacity: 0.4; cursor: not-allowed; }
.btn--primary { background: var(--color-primary); color: var(--color-text-inverse); }
.btn--primary:not(:disabled):hover { background: var(--color-primary-hover); }
.btn--primary:not(:disabled):active { background: var(--color-primary-active); }
.btn--ghost { background: transparent; color: var(--color-text-muted); border-color: var(--color-border); }
.btn--ghost:not(:disabled):hover { background: var(--color-surface-offset); color: var(--color-text); }
'@ | Set-Content "$base\src\components\HintSection\HintSection.css" -Encoding UTF8

Write-Host "[12/14] HintSection component written." -ForegroundColor Cyan

# ─── SimilarProblems Component ────────────────────────────────────────────────
@'
import React from "react";
import "./SimilarProblems.css";

const DIFFICULTY_CLS = {
  Easy:   "problem-item__difficulty--easy",
  Medium: "problem-item__difficulty--medium",
  Hard:   "problem-item__difficulty--hard",
};

export default function SimilarProblems({ problems, loading, hasProblem }) {
  return (
    <section className="section-card similar-problems" aria-label="Similar problems">
      <p className="section-title">Similar Problems</p>

      {!hasProblem && !loading && (
        <p className="similar-problems__placeholder">
          Detected problem will surface related questions here.
        </p>
      )}

      {loading && (
        <ul className="similar-problems__list" aria-busy="true">
          {Array.from({ length: 4 }, (_, i) => (
            <li key={i} className="problem-item problem-item--skeleton">
              <div className="skeleton skeleton--problem-title" />
              <div className="skeleton skeleton--problem-diff" />
            </li>
          ))}
        </ul>
      )}

      {!loading && problems.length > 0 && (
        <ul className="similar-problems__list">
          {problems.map((p) => (
            <li key={p.id}>
              <a
                className="problem-item"
                href={p.url}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${p.title} - ${p.difficulty}`}
              >
                <span className="problem-item__number">#{p.number}</span>
                <span className="problem-item__title">{p.title}</span>
                <span className={`problem-item__difficulty ${DIFFICULTY_CLS[p.difficulty] ?? ""}`}>
                  {p.difficulty}
                </span>
                <span className="problem-item__arrow" aria-hidden="true">&#8599;</span>
              </a>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
'@ | Set-Content "$base\src\components\SimilarProblems\SimilarProblems.js" -Encoding UTF8

@'
.similar-problems__placeholder { font-size: var(--text-sm); color: var(--color-text-muted); line-height: 1.5; }
.similar-problems__list { display: flex; flex-direction: column; gap: 1px; }
.problem-item { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-1); border-radius: var(--radius-md); text-decoration: none; transition: background var(--transition); color: var(--color-text); cursor: pointer; }
.problem-item:hover { background: var(--color-surface-offset); text-decoration: none; }
.problem-item:hover .problem-item__arrow { opacity: 1; transform: translate(1px, -1px); }
.problem-item__number { font-size: var(--text-xs); font-family: var(--font-mono); color: var(--color-text-faint); width: 30px; flex-shrink: 0; }
.problem-item__title { flex: 1; font-size: var(--text-sm); color: var(--color-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.problem-item__difficulty { font-size: var(--text-xs); font-weight: 600; flex-shrink: 0; }
.problem-item__difficulty--easy   { color: var(--color-easy);   }
.problem-item__difficulty--medium { color: var(--color-medium); }
.problem-item__difficulty--hard   { color: var(--color-hard);   }
.problem-item__arrow { font-size: var(--text-xs); color: var(--color-text-faint); opacity: 0; transition: opacity var(--transition), transform var(--transition); flex-shrink: 0; }
.problem-item--skeleton { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-1); pointer-events: none; }
.skeleton--problem-title { height: 13px; flex: 1; }
.skeleton--problem-diff  { height: 11px; width: 40px; flex-shrink: 0; }
'@ | Set-Content "$base\src\components\SimilarProblems\SimilarProblems.css" -Encoding UTF8

Write-Host "[13/14] SimilarProblems component written." -ForegroundColor Cyan

# ─── StatusBar Component ──────────────────────────────────────────────────────
@'
import React from "react";
import "./StatusBar.css";

const STATUS_CONFIG = {
  loading:      { label: "Detecting problem...", cls: "status--loading",    dot: true  },
  ready:        { label: "Ready",                cls: "status--ready",      dot: true  },
  "no-problem": { label: "No problem detected",  cls: "status--idle",       dot: false },
  error:        { label: "Error",                cls: "status--error",      dot: true  },
};

export default function StatusBar({ status, error }) {
  const config = STATUS_CONFIG[status] ?? STATUS_CONFIG["no-problem"];
  const label = status === "error" && error ? `Error: ${error}` : config.label;

  return (
    <footer className={`status-bar ${config.cls}`} role="status" aria-live="polite">
      {config.dot && <span className="status-bar__dot" aria-hidden="true" />}
      <span className="status-bar__label">{label}</span>
      <span className="status-bar__brand">leettow v1.0</span>
    </footer>
  );
}
'@ | Set-Content "$base\src\components\StatusBar\StatusBar.js" -Encoding UTF8

@'
.status-bar { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-4); background: var(--color-surface); border-top: 1px solid var(--color-border); flex-shrink: 0; }
.status-bar__dot { width: 6px; height: 6px; border-radius: var(--radius-full); flex-shrink: 0; }
.status-bar__label { flex: 1; font-size: var(--text-xs); color: var(--color-text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.status-bar__brand { font-size: var(--text-xs); color: var(--color-text-faint); font-family: var(--font-mono); flex-shrink: 0; }
.status--loading .status-bar__dot { background: var(--color-warning); animation: pulse 1.2s ease-in-out infinite; }
.status--ready   .status-bar__dot { background: var(--color-success); }
.status--error   .status-bar__dot { background: var(--color-error);   }
.status--loading .status-bar__label { color: var(--color-warning); }
.status--ready   .status-bar__label { color: var(--color-success); }
.status--error   .status-bar__label { color: var(--color-error);   }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
'@ | Set-Content "$base\src\components\StatusBar\StatusBar.css" -Encoding UTF8

Write-Host "[14/14] StatusBar component written." -ForegroundColor Cyan

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  LeetTow frontend scaffold complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. cd $base" -ForegroundColor White
Write-Host "  2. npm install" -ForegroundColor White
Write-Host "  3. npm run build:ext" -ForegroundColor White
Write-Host "  4. Add PNG icons to public\icons\ (16, 48, 128px)" -ForegroundColor White
Write-Host "  5. Load the build\ folder as unpacked extension in chrome://extensions" -ForegroundColor White
Write-Host ""
