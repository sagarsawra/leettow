/**
 * background.js — Manifest V3 Service Worker
 * Central hub: caches problem data, serves hints and similar problems.
 * Routes all data through the backend API for real AI-powered responses.
 */

const BACKEND_URL = "http://localhost:3001";

/** Per-tab cache: { problemData, analysis: { hintLevels, similarProblems } } */
const tabCache = new Map();

/* ------------------------------------------------------------------ */
/*  Fallback data — used when the backend is unreachable               */
/* ------------------------------------------------------------------ */
const FALLBACK_HINTS = [
  "Think about the core data structure that naturally models this problem's constraints. What property must hold at every step?",
  "Consider how sorting or a specific traversal order might expose a pattern. Can you reduce this to a known subproblem?",
  "Think about the trade-off between time and space. Accepting extra memory often unlocks a significantly faster traversal strategy.",
];

const FALLBACK_SIMILAR = [
  { id: 1, number: 1, title: "Two Sum", difficulty: "Easy", url: "https://leetcode.com/problems/two-sum/" },
  { id: 3, number: 3, title: "Longest Substring Without Repeating Characters", difficulty: "Medium", url: "https://leetcode.com/problems/longest-substring-without-repeating-characters/" },
  { id: 15, number: 15, title: "3Sum", difficulty: "Medium", url: "https://leetcode.com/problems/3sum/" },
];

/* ------------------------------------------------------------------ */
/*  Backend API call                                                   */
/* ------------------------------------------------------------------ */
async function fetchAnalysis(problemData) {
  try {
    const response = await fetch(`${BACKEND_URL}/api/problem/analyze`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: problemData.title,
        difficulty: problemData.difficulty || "Unknown",
        tags: problemData.tags || [],
      }),
    });

    if (!response.ok) {
      console.warn("[LeetTow BG] Backend returned", response.status);
      return null;
    }

    const body = await response.json();
    if (!body.success || !body.data) return null;

    return {
      hintLevels: body.data.hintLevels || FALLBACK_HINTS,
      similarProblems: (body.data.similarProblems || []).map((p, i) => ({
        id: i,
        number: i + 1,
        title: p.title,
        difficulty: p.difficulty,
        url: p.link || p.url,
      })),
    };
  } catch (err) {
    console.warn("[LeetTow BG] Backend unreachable:", err.message);
    return null;
  }
}

/**
 * Get or fetch analysis for a tab's cached problem data.
 * Returns { hintLevels, similarProblems } — always valid.
 */
async function getAnalysis(tabId) {
  const entry = tabCache.get(tabId);
  if (!entry?.problemData) return null;

  // Return cached analysis if available
  if (entry.analysis) return entry.analysis;

  // Fetch from backend
  const analysis = await fetchAnalysis(entry.problemData);
  if (analysis) {
    entry.analysis = analysis;
    return analysis;
  }

  // Fallback
  const fallback = { hintLevels: FALLBACK_HINTS, similarProblems: FALLBACK_SIMILAR };
  entry.analysis = fallback;
  return fallback;
}

/* ------------------------------------------------------------------ */
/*  Message handler                                                    */
/* ------------------------------------------------------------------ */
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.type) {

    case "PROBLEM_DETECTED": {
      if (sender.tab?.id) {
        const existing = tabCache.get(sender.tab.id);
        const newTitle = message.payload.title;

        // Only reset analysis if the problem actually changed
        if (existing?.problemData?.title !== newTitle) {
          tabCache.set(sender.tab.id, {
            problemData: {
              title: newTitle,
              difficulty: message.payload.difficulty,
              tags: message.payload.tags,
              detectedAt: Date.now(),
            },
            analysis: null, // will be fetched on demand
          });
        }
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
        const entry = tabCache.get(activeTab.id);
        if (entry?.problemData) {
          sendResponse({ success: true, data: entry.problemData });
          return;
        }
        // Try to extract from the page directly
        chrome.scripting.executeScript(
          { target: { tabId: activeTab.id }, func: extractProblemFromDOM },
          (results) => {
            if (chrome.runtime.lastError || !results?.[0]?.result) {
              sendResponse({ success: false, error: "Not on a problem page." });
              return;
            }
            const data = results[0].result;
            tabCache.set(activeTab.id, { problemData: data, analysis: null });
            sendResponse({ success: true, data });
          }
        );
      });
      return true; // async response
    }

    case "GET_HINT": {
      chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
        const tabId = tabs[0]?.id;
        if (!tabId) {
          sendResponse({ success: false, error: "No active tab." });
          return;
        }
        try {
          const analysis = await getAnalysis(tabId);
          const hintLevel = message.payload?.hintLevel ?? 1;
          const hint = analysis?.hintLevels?.[hintLevel - 1] ?? FALLBACK_HINTS[0];
          sendResponse({ success: true, hint });
        } catch (err) {
          sendResponse({ success: true, hint: FALLBACK_HINTS[0] });
        }
      });
      return true; // async response
    }

    case "GET_SIMILAR_PROBLEMS": {
      chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
        const tabId = tabs[0]?.id;
        if (!tabId) {
          sendResponse({ success: false, error: "No active tab." });
          return;
        }
        try {
          const analysis = await getAnalysis(tabId);
          sendResponse({ success: true, problems: analysis?.similarProblems ?? FALLBACK_SIMILAR });
        } catch (err) {
          sendResponse({ success: true, problems: FALLBACK_SIMILAR });
        }
      });
      return true; // async response
    }

    default:
      sendResponse({ success: false, error: `Unknown message type: ${message.type}` });
  }
});

/* ------------------------------------------------------------------ */
/*  Cleanup on tab close                                               */
/* ------------------------------------------------------------------ */
chrome.tabs.onRemoved.addListener((tabId) => {
  tabCache.delete(tabId);
});

/* ------------------------------------------------------------------ */
/*  DOM extraction (injected into the page)                            */
/* ------------------------------------------------------------------ */
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
