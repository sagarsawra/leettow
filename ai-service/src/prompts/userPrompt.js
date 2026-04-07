/**
 * userPrompt.js â€” Formats the incoming problem data into a structured prompt.
 *
 * Design decisions:
 *   1. The user prompt is kept minimal â€” the system prompt carries the rules.
 *   2. Fields are explicitly labelled so the model can extract them reliably.
 *   3. Unknown difficulty is sent as "Not specified" rather than "Unknown"
 *      because "Unknown" can confuse some models into treating it as valid data.
 *   4. Description is truncated to prevent token overflow while preserving
 *      the most relevant context (first 800 chars is usually the problem statement).
 */

const MAX_DESCRIPTION_LENGTH = 800;

/**
 * Build the user turn for the hint generation request.
 * @param {{ title: string, description?: string, difficulty?: string }} problem
 * @returns {string}
 */
function buildUserPrompt(problem) {
  const title       = problem.title.trim();
  const difficulty  = problem.difficulty?.trim() || "Not specified";
  const description = problem.description
    ? problem.description.trim().slice(0, MAX_DESCRIPTION_LENGTH)
    : "Not provided";

  return `
Generate 3 progressive hints for the following coding problem.
Follow all rules from your system instructions exactly.

PROBLEM TITLE: ${title}
DIFFICULTY: ${difficulty}
DESCRIPTION: ${description}

Return ONLY the JSON object. No other text.
`.trim();
}

module.exports = { buildUserPrompt };
