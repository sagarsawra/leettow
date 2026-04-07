/**
 * hintParser.js â€” Parses and validates the raw LLM response.
 *
 * Why a dedicated parser?
 *   LLMs are non-deterministic. Even with json_object mode and strict prompting,
 *   the model may return unexpected shapes. This parser is the contract enforcer
 *   between the LLM and our API. All validation logic lives here so the service
 *   layer stays clean.
 */
const logger = require("../config/logger");

const EXPECTED_HINTS = 3;
const MIN_HINT_LENGTH = 20;
const MAX_HINT_LENGTH = 600;

/**
 * Parse the raw JSON string from the LLM into a validated hints array.
 * @param {string} rawContent
 * @returns {{ valid: boolean, hints: string[]|null, reason: string|null }}
 */
function parseHintResponse(rawContent) {
  let parsed;
  try {
    parsed = JSON.parse(rawContent);
  } catch (e) {
    logger.warn("LLM response is not valid JSON", { raw: rawContent.slice(0, 200) });
    return { valid: false, hints: null, reason: "Response is not valid JSON." };
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { valid: false, hints: null, reason: "Response is not a JSON object." };
  }

  const hints = parsed.hintLevels;

  if (!Array.isArray(hints)) {
    logger.warn("LLM response missing hintLevels array", { keys: Object.keys(parsed) });
    return { valid: false, hints: null, reason: "hintLevels is not an array." };
  }

  if (hints.length !== EXPECTED_HINTS) {
    logger.warn("LLM returned wrong number of hints", { count: hints.length });
    return { valid: false, hints: null, reason: `Expected ${EXPECTED_HINTS} hints, got ${hints.length}.` };
  }

  for (let i = 0; i < hints.length; i++) {
    if (typeof hints[i] !== "string") {
      return { valid: false, hints: null, reason: `Hint ${i + 1} is not a string.` };
    }
    const trimmed = hints[i].trim();
    if (trimmed.length < MIN_HINT_LENGTH) {
      logger.warn("Hint suspiciously short", { index: i, length: trimmed.length });
      return { valid: false, hints: null, reason: `Hint ${i + 1} is too short to be useful.` };
    }
    hints[i] = trimmed.slice(0, MAX_HINT_LENGTH);
  }

  return { valid: true, hints, reason: null };
}

module.exports = { parseHintResponse };
