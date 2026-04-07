const { Router }         = require("express");
const { analyzeProblem } = require("../controllers/problem.controller");

const router = Router();

/**
 * POST /api/problem/analyze
 * Body: { title, description?, difficulty?, tags? }
 * Response: { success, data: { problemTitle, hintLevels, similarProblems } }
 */
router.post("/problem/analyze", analyzeProblem);

module.exports = router;
