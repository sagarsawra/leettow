/**
 * hint.controller.js â€” Handles POST /generate-hint.
 */
const { validateGenerateHint } = require("../validators/hint.validator");
const { generateHints }        = require("../../services/hintService");
const asyncHandler             = require("../../utils/asyncHandler");
const AppError                 = require("../../utils/AppError");
const { ok }                   = require("../../utils/respond");

const generateHint = asyncHandler(async (req, res) => {
  const { value, error } = validateGenerateHint(req.body);

  if (error) {
    const messages = error.details.map((d) => d.message).join("; ");
    throw new AppError(messages, 400);
  }

  // generateHints ALWAYS returns a valid { hintLevels } object.
  // AI failures degrade to fallback â€” they never throw to the controller.
  const result = await generateHints(value);

  return ok(res, result);
});

module.exports = { generateHint };
