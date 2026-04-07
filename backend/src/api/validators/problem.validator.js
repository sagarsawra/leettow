/**
 * problem.validator.js â€” Joi schema for problem analysis requests.
 */
const Joi = require("joi");

const analyzeProblemSchema = Joi.object({
  title: Joi.string().trim().min(2).max(200).required().messages({
    "string.empty": "Problem title is required.",
    "string.min":   "Problem title must be at least 2 characters.",
    "string.max":   "Problem title must not exceed 200 characters.",
    "any.required": "Problem title is required.",
  }),
  description: Joi.string().trim().max(5000).optional().allow(""),
  difficulty:  Joi.string().valid("Easy", "Medium", "Hard", "Unknown").optional().default("Unknown"),
  tags:        Joi.array().items(Joi.string().trim().max(50)).max(10).optional().default([]),
});

function validateAnalyzeProblem(body) {
  return analyzeProblemSchema.validate(body, {
    abortEarly:    false,
    stripUnknown:  true,
  });
}

module.exports = { validateAnalyzeProblem };
