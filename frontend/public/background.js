/**
 * background.js â€” Manifest V3 Service Worker
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
