/**
 * problemService.js — Orchestrates AI hints + recommendations in parallel.
 */
const aiService = require("./ai/aiService");
const recommender = require("./recommender");
const logger = require("../config/logger");

async function analyzeProblem(problem) {
  logger.info("Analysing problem", {
    title: problem.title,
    difficulty: problem.difficulty,
  });

  const [hintsResult, recsResult] = await Promise.allSettled([
    aiService.getHints(problem),
    Promise.resolve(recommender.getSimilarProblems(problem)),
  ]);

  const hintLevels = hintsResult.status === "fulfilled"
    ? hintsResult.value
    : (() => { logger.warn("Hints failed in orchestrator", { error: hintsResult.reason?.message }); return []; })();

  const similarProblems = recsResult.status === "fulfilled"
    ? recsResult.value
    : (() => { logger.warn("Recommender failed in orchestrator", { error: recsResult.reason?.message }); return []; })();

  return {
    problemTitle: problem.title,
    hintLevels,
    similarProblems,
  };
}

module.exports = { analyzeProblem };