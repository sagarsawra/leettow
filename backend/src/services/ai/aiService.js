/**
 * aiService.js — AI business logic layer.
 * Calls the AI client, validates the response, falls back gracefully.
 */
const aiClient = require("./aiClient");
const logger   = require("../../config/logger");

const FALLBACK_HINTS = {
  Easy: [
    "Consider what information you already have and what you need to find. Is there a simple relationship between them?",
    "Think about what structure would let you store and retrieve information efficiently as you scan through the input.",
    "A single pass through the data is likely sufficient. As you iterate, think about what state you need to track at each step to avoid redundant work.",
  ],
  Medium: [
    "Step back from the details. What is the core decision this problem is asking you to make at each step?",
    "Consider whether pre-processing the input — sorting it, indexing it, or transforming it — changes what operations become cheap versus expensive.",
    "Think about the trade-off between time and space. Accepting extra memory often unlocks a significantly faster traversal strategy. What would you store, and when would you look it up?",
  ],
  Hard: [
    "Hard problems are usually combinations of simpler subproblems. Can you decompose this into two or three problems you already know how to solve?",
    "Consider whether you are solving the same subproblem multiple times. If so, there is likely a way to store intermediate results to avoid recomputation.",
    "Think about the problem in reverse, or from the perspective of the optimal answer. What properties must a valid solution have, and can you build toward those properties incrementally?",
  ],
};

function getFallbackHints(difficulty) {
  return FALLBACK_HINTS[difficulty] ?? FALLBACK_HINTS.Medium;
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
      logger.warn("AI service returned unexpected hint shape — using fallback", { hints });
      return getFallbackHints(problem.difficulty);
    }
    return hints;
  } catch (err) {
    logger.warn("AI hint fetch failed — using fallback hints", {
      error: err.message,
      title: problem.title,
    });
    return getFallbackHints(problem.difficulty);
  }
}

module.exports = { getHints };
