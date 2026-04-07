/**
 * problemService.js â€” Orchestrates AI hints + recommendations in parallel.
 */
const aiService   = require("./ai/aiService");
const recommender = require("./recommender");
const logger      = require("../config/logger");

async function analyzeProblem(problem) {
  logger.info("Analysing problem", { title: problem.title, difficulty: problem.difficulty });

  const [hintLevels, similarProblems] = await Promise.all([
    aiService.getHints(problem),
    Promise.resolve(recommender.getSimilarProblems(problem)),
  ]);

  return {
    problemTitle: problem.title,
    hintLevels,
    similarProblems,
  };
}

module.exports = { analyzeProblem };
