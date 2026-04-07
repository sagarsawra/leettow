/**
 * fallbackHints.js â€” Deterministic difficulty-aware fallback hints.
 *
 * Used when the LLM call fails, times out, or returns unparseable output.
 * A degraded-but-functional response is always better than an error
 * from the user's perspective.
 */

const FALLBACKS = {
  Easy: [
    "Consider what information you already have and what you need to find. Is there a simple relationship between them?",
    "Think about what structure would let you store and retrieve information efficiently as you scan through the input.",
    "A single pass through the data is likely sufficient. As you iterate, think about what state you need to track at each step to avoid redundant work.",
  ],
  Medium: [
    "Step back from the details. What is the core decision this problem is asking you to make at each step?",
    "Consider whether pre-processing the input â€” sorting it, indexing it, or transforming it â€” changes what operations become cheap versus expensive.",
    "Think about the trade-off between time and space. Accepting extra memory often unlocks a significantly faster traversal strategy. What would you store, and when would you look it up?",
  ],
  Hard: [
    "Hard problems are usually combinations of simpler subproblems. Can you decompose this into two or three problems you already know how to solve?",
    "Consider whether you are solving the same subproblem multiple times. If so, there is likely a way to store intermediate results to avoid recomputation.",
    "Think about the problem in reverse, or from the perspective of the optimal answer. What properties must a valid solution have, and can you build toward those properties incrementally?",
  ],
};

const DEFAULT_FALLBACK = FALLBACKS.Medium;

/**
 * Get fallback hints for a given difficulty level.
 * @param {string} [difficulty] "Easy" | "Medium" | "Hard"
 * @returns {string[]} Array of exactly 3 hint strings.
 */
function getFallbackHints(difficulty) {
  return FALLBACKS[difficulty] ?? DEFAULT_FALLBACK;
}

module.exports = { getFallbackHints };
