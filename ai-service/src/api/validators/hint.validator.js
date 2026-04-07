/**
 * hint.validator.js â€” Joi schema for POST /generate-hint requests.
 */
const Joi = require("joi");

const generateHintSchema = Joi.object({
  title: Joi.string().trim().min(2).max(200).required().messages({
    "string.empty": "Problem title is required.",
    "string.min":   "Problem title must be at least 2 characters.",
    "any.required": "Problem title is required.",
  }),
  description: Joi.string().trim().max(5000).optional().allow(""),
  difficulty:  Joi.string().valid("Easy", "Medium", "Hard", "Unknown").optional().default("Unknown"),
});

function validateGenerateHint(body) {
  return generateHintSchema.validate(body, {
    abortEarly:   false,
    stripUnknown: true,
  });
}

module.exports = { validateGenerateHint };
