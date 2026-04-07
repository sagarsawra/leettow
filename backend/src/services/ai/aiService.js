/**
 * aiService.js â€” AI business logic layer.
 * Calls the AI client, validates the response, falls back gracefully.
 */
const aiClient = require("./aiClient");
const logger   = require("../../config/logger");

function buildFallbackHints(title) {
  return [
    `Think about which data structure gives you the best time complexity for this problem. What property must hold at every step?`,
    `Consider whether sorting the input or using a specific traversal order reveals a pattern. Can you reduce "${title}" to a simpler known subproblem?`,
    `A two-pointer or sliding window approach often achieves O(n) for this class of problem. Define the invariant your window must maintain, then determine when to expand or shrink it.`,
  ];
}

function isValidHintResponse(hints) {
  return (
    Array.isArray(hints) &&
    hints.length === 3 &&
    hints.every((h) => typeof h === "string" && h.trim().length > 0)
  );
}

async function getHints(problem) {
  try {
    const hints = await aiClient.requestHints(problem);
    if (!isValidHintResponse(hints)) {
      logger.warn("AI service returned unexpected hint shape â€” using fallback", { hints });
      return buildFallbackHints(problem.title);
    }
    return hints;
  } catch (err) {
    logger.warn("AI hint fetch failed â€” using fallback hints", {
      error: err.message,
      title: problem.title,
    });
    return buildFallbackHints(problem.title);
  }
}

module.exports = { getHints };
