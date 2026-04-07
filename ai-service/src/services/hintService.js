/**
 * hintService.js â€” Orchestrates the full hint generation flow.
 *
 * Flow:
 *   1. Build system + user prompts.
 *   2. Call OpenAI via the client adapter.
 *   3. Parse and validate the response.
 *   4. If parsing fails, retry ONCE (models occasionally produce malformed output).
 *   5. If retry also fails, degrade to difficulty-aware fallback hints.
 *   6. If the AI call itself throws, degrade immediately to fallback.
 *
 * The caller (controller) always receives { hintLevels: string[] } â€” never an error
 * caused by an AI failure. Failures are logged for observability but hidden from clients.
 *
 * Why one retry?
 *   A single retry on parse failure catches transient LLM formatting errors without
 *   significantly increasing latency or cost. Two retries would double worst-case cost.
 */
const SYSTEM_PROMPT         = require("../prompts/systemPrompt");
const { buildUserPrompt }   = require("../prompts/userPrompt");
const { callOpenAI }        = require("./openaiClient");
const { parseHintResponse } = require("./hintParser");
const { getFallbackHints }  = require("./fallbackHints");
const logger                = require("../config/logger");

const MAX_RETRIES = 1;

/**
 * Generate structured hints for a coding problem.
 * @param {{ title: string, description?: string, difficulty?: string }} problem
 * @returns {Promise<{ hintLevels: string[] }>}
 */
async function generateHints(problem) {
  const userPrompt = buildUserPrompt(problem);
  let attempts = 0;

  while (attempts <= MAX_RETRIES) {
    attempts++;

    try {
      logger.info("Generating hints", {
        title:      problem.title,
        difficulty: problem.difficulty,
        attempt:    attempts,
      });

      const rawContent = await callOpenAI(SYSTEM_PROMPT, userPrompt);
      const { valid, hints, reason } = parseHintResponse(rawContent);

      if (valid) {
        logger.info("Hints generated successfully", { title: problem.title, attempt: attempts });
        return { hintLevels: hints };
      }

      logger.warn("Hint parsing failed", { reason, attempt: attempts, willRetry: attempts <= MAX_RETRIES });

    } catch (err) {
      logger.error("AI call failed â€” using fallback", {
        title:   problem.title,
        message: err.message,
        status:  err.statusCode,
      });
      break;
    }
  }

  logger.warn("Returning fallback hints", { title: problem.title, difficulty: problem.difficulty });
  return { hintLevels: getFallbackHints(problem.difficulty) };
}

module.exports = { generateHints };
