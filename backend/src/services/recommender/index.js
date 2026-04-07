/**
 * recommender/index.js â€” Tag-weighted Jaccard similarity recommender.
 *
 * Scoring (three passes):
 *   Pass 1: Tag Jaccard similarity        (weight 0.60)
 *   Pass 2: Keyword / title token overlap (weight 0.30)
 *   Pass 3: Difficulty affinity bonus     (weight 0.10)
 *
 * Extensibility: replace scoreCandidate with an embedding-based scorer
 * and nothing else in the codebase needs to change.
 */
const PROBLEMS = require("../../data/problems");

const MAX_RESULTS = 5;

const DIFFICULTY_SCORE = {
  "Easy-Easy":     1.0, "Easy-Medium":   0.5, "Easy-Hard":     0.0,
  "Medium-Easy":   0.5, "Medium-Medium": 1.0, "Medium-Hard":   0.5,
  "Hard-Easy":     0.0, "Hard-Medium":   0.5, "Hard-Hard":     1.0,
};

const STOP_WORDS = new Set(["a","an","the","in","of","to","and","or","is","are","for","with"]);

function tokenise(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 1 && !STOP_WORDS.has(w));
}

function jaccard(setA, setB) {
  if (!setA.size && !setB.size) return 0;
  const intersection = new Set([...setA].filter((x) => setB.has(x)));
  const union = new Set([...setA, ...setB]);
  return intersection.size / union.size;
}

function scoreCandidate(query, problem) {
  const queryTags     = new Set((query.tags || []).map((t) => t.toLowerCase()));
  const candidateTags = new Set(problem.tags.map((t) => t.toLowerCase()));
  const tagScore      = jaccard(queryTags, candidateTags);

  const queryTokens = new Set([
    ...tokenise(query.title),
    ...(query.tags || []).flatMap((t) => tokenise(t)),
  ]);
  const problemTokens = new Set([...tokenise(problem.title), ...problem.keywords]);
  const keywordScore  = jaccard(queryTokens, problemTokens);

  const diffKey  = `${query.difficulty || "Unknown"}-${problem.difficulty}`;
  const diffScore = DIFFICULTY_SCORE[diffKey] ?? 0.5;

  return tagScore * 0.60 + keywordScore * 0.30 + diffScore * 0.10;
}

function getSimilarProblems(query, limit = MAX_RESULTS) {
  const normTitle = query.title.trim().toLowerCase();

  return PROBLEMS
    .filter((p) => p.title.toLowerCase() !== normTitle)
    .map((p) => ({ problem: p, score: scoreCandidate(query, p) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(({ problem }) => ({
      title:      problem.title,
      difficulty: problem.difficulty,
      link:       problem.link,
    }));
}

module.exports = { getSimilarProblems, scoreCandidate };
