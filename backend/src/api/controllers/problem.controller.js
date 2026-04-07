/**
 * problem.controller.js â€” Handles POST /api/problem/analyze.
 */
const { validateAnalyzeProblem } = require("../validators/problem.validator");
const problemService             = require("../../services/problemService");
const asyncHandler               = require("../../utils/asyncHandler");
const AppError                   = require("../../utils/AppError");
const { ok }                     = require("../../utils/respond");

const analyzeProblem = asyncHandler(async (req, res) => {
  const { value, error } = validateAnalyzeProblem(req.body);

  if (error) {
    const messages = error.details.map((d) => d.message).join("; ");
    throw new AppError(messages, 400);
  }

  const result = await problemService.analyzeProblem(value);
  return ok(res, result);
});

module.exports = { analyzeProblem };
