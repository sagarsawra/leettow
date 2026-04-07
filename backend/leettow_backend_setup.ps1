# LeetTow Backend Setup Script
# Creates the full backend at: C:\Users\lenovo\Documents\GitHub\leettow\backend
# Usage: .\leettow_backend_setup.ps1

$base = "C:\Users\lenovo\Documents\GitHub\leettow\backend"

# ─── Folder Structure ─────────────────────────────────────────────────────────
$folders = @(
    "$base\src\config",
    "$base\src\data",
    "$base\src\utils",
    "$base\src\services\ai",
    "$base\src\services\recommender",
    "$base\src\api\controllers",
    "$base\src\api\middleware",
    "$base\src\api\validators",
    "$base\src\api\routes",
    "$base\tests"
)
foreach ($f in $folders) { New-Item -ItemType Directory -Force -Path $f | Out-Null }
Write-Host "[1/15] Folders created." -ForegroundColor Cyan

# ─── package.json ─────────────────────────────────────────────────────────────
@'
{
  "name": "leettow-backend",
  "version": "1.0.0",
  "description": "LeetTow backend — AI hints and problem recommendations for coding platforms",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest --runInBand --forceExit"
  },
  "dependencies": {
    "axios": "^1.6.7",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.18.3",
    "express-rate-limit": "^7.2.0",
    "helmet": "^7.1.0",
    "joi": "^17.12.2",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "nodemon": "^3.1.0",
    "supertest": "^6.3.4"
  }
}
'@ | Set-Content "$base\package.json" -Encoding UTF8

# ─── .env.example ─────────────────────────────────────────────────────────────
@'
# Server
PORT=3001
NODE_ENV=development

# AI Service
AI_SERVICE_URL=http://localhost:5000
AI_SERVICE_TIMEOUT_MS=8000
AI_SERVICE_API_KEY=

# CORS — comma-separated list of allowed origins
ALLOWED_ORIGINS=chrome-extension://,http://localhost:3000

# Rate limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=30
'@ | Set-Content "$base\.env.example" -Encoding UTF8

# ─── .gitignore ───────────────────────────────────────────────────────────────
@'
node_modules/
.env
*.log
coverage/
'@ | Set-Content "$base\.gitignore" -Encoding UTF8

Write-Host "[2/15] package.json, .env.example, .gitignore written." -ForegroundColor Cyan

# ─── src/server.js ────────────────────────────────────────────────────────────
@'
/**
 * server.js — Entry point.
 * Separated from app.js so tests can import the app without binding a port.
 */
const app    = require("./app");
const config = require("./config");
const logger = require("./config/logger");

const server = app.listen(config.port, () => {
  logger.info("LeetTow backend running", {
    port:      config.port,
    env:       config.env,
    aiService: config.aiService.url,
  });
});

function shutdown(signal) {
  logger.info(`${signal} received — shutting down gracefully`);
  server.close(() => {
    logger.info("HTTP server closed");
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT",  () => shutdown("SIGINT"));

process.on("unhandledRejection", (reason) => {
  logger.error("Unhandled rejection", { reason: String(reason) });
  process.exit(1);
});
'@ | Set-Content "$base\src\server.js" -Encoding UTF8

# ─── src/app.js ───────────────────────────────────────────────────────────────
@'
/**
 * app.js — Express application factory.
 */
const express  = require("express");
const helmet   = require("helmet");
const cors     = require("cors");
const morgan   = require("morgan");

const config       = require("./config");
const routes       = require("./api/routes");
const errorHandler = require("./api/middleware/errorHandler");
const rateLimiter  = require("./api/middleware/rateLimiter");

const app = express();

app.use(helmet());

app.use(cors({
  origin(origin, cb) {
    if (!origin) return cb(null, true);
    const allowed = config.cors.allowedOrigins.some((o) => origin.startsWith(o));
    allowed ? cb(null, true) : cb(new Error(`CORS: origin '${origin}' not allowed`));
  },
  methods: ["GET", "POST"],
}));

app.use(express.json({ limit: "50kb" }));

if (config.env !== "test") {
  app.use(morgan("short"));
}

app.use("/api", rateLimiter);
app.use("/api", routes);

app.use((req, res) => {
  res.status(404).json({ success: false, error: "Route not found." });
});

app.use(errorHandler);

module.exports = app;
'@ | Set-Content "$base\src\app.js" -Encoding UTF8

Write-Host "[3/15] server.js + app.js written." -ForegroundColor Cyan

# ─── src/config/index.js ──────────────────────────────────────────────────────
@'
/**
 * config/index.js — Single source of truth for runtime configuration.
 */
require("dotenv").config();

const config = {
  env:  process.env.NODE_ENV || "development",
  port: parseInt(process.env.PORT, 10) || 3001,

  cors: {
    allowedOrigins: (process.env.ALLOWED_ORIGINS || "")
      .split(",")
      .map((o) => o.trim())
      .filter(Boolean),
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 60_000,
    max:      parseInt(process.env.RATE_LIMIT_MAX, 10) || 30,
  },

  aiService: {
    url:       process.env.AI_SERVICE_URL || "http://localhost:5000",
    timeoutMs: parseInt(process.env.AI_SERVICE_TIMEOUT_MS, 10) || 8_000,
    apiKey:    process.env.AI_SERVICE_API_KEY || "",
  },
};

module.exports = config;
'@ | Set-Content "$base\src\config\index.js" -Encoding UTF8

# ─── src/config/logger.js ─────────────────────────────────────────────────────
@'
/**
 * config/logger.js — Lightweight structured logger.
 * Swap for Winston/Pino in production without touching callers.
 */
const config = require("./index");

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const currentLevel = config.env === "production" ? LEVELS.info : LEVELS.debug;

function log(level, message, meta = {}) {
  if (LEVELS[level] > currentLevel) return;
  const entry = {
    ts: new Date().toISOString(),
    level,
    message,
    ...(Object.keys(meta).length ? { meta } : {}),
  };
  const output = JSON.stringify(entry);
  level === "error" ? console.error(output) : console.log(output);
}

const logger = {
  error: (msg, meta) => log("error", msg, meta),
  warn:  (msg, meta) => log("warn",  msg, meta),
  info:  (msg, meta) => log("info",  msg, meta),
  debug: (msg, meta) => log("debug", msg, meta),
};

module.exports = logger;
'@ | Set-Content "$base\src\config\logger.js" -Encoding UTF8

Write-Host "[4/15] config/index.js + logger.js written." -ForegroundColor Cyan

# ─── src/utils/AppError.js ────────────────────────────────────────────────────
@'
/**
 * AppError.js — Domain error with HTTP status code.
 */
class AppError extends Error {
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    this.name          = "AppError";
    this.statusCode    = statusCode;
    this.isOperational = isOperational;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
'@ | Set-Content "$base\src\utils\AppError.js" -Encoding UTF8

# ─── src/utils/asyncHandler.js ────────────────────────────────────────────────
@'
/**
 * asyncHandler.js — Wraps async route handlers, forwarding rejections to next(err).
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;
'@ | Set-Content "$base\src\utils\asyncHandler.js" -Encoding UTF8

# ─── src/utils/respond.js ─────────────────────────────────────────────────────
@'
/**
 * respond.js — Normalised API response helpers.
 */
function ok(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, data });
}

function fail(res, message, statusCode = 500) {
  return res.status(statusCode).json({ success: false, error: message });
}

module.exports = { ok, fail };
'@ | Set-Content "$base\src\utils\respond.js" -Encoding UTF8

Write-Host "[5/15] utils written." -ForegroundColor Cyan

# ─── src/api/middleware/errorHandler.js ───────────────────────────────────────
@'
/**
 * errorHandler.js — Centralised Express error handler.
 */
const logger   = require("../../config/logger");
const AppError = require("../../utils/AppError");
const config   = require("../../config");

// eslint-disable-next-line no-unused-vars
module.exports = function errorHandler(err, req, res, next) {
  if (err.isJoi) {
    return res.status(400).json({
      success: false,
      error: err.details.map((d) => d.message).join("; "),
    });
  }

  if (err instanceof AppError && err.isOperational) {
    logger.warn("Operational error", { message: err.message, statusCode: err.statusCode });
    return res.status(err.statusCode).json({ success: false, error: err.message });
  }

  logger.error("Unexpected error", {
    message: err.message,
    stack:   config.env !== "production" ? err.stack : undefined,
  });

  return res.status(500).json({
    success: false,
    error: config.env === "production"
      ? "An unexpected error occurred. Please try again."
      : err.message,
  });
};
'@ | Set-Content "$base\src\api\middleware\errorHandler.js" -Encoding UTF8

# ─── src/api/middleware/rateLimiter.js ────────────────────────────────────────
@'
/**
 * rateLimiter.js — express-rate-limit configured via env vars.
 */
const rateLimit = require("express-rate-limit");
const config    = require("../../config");

module.exports = rateLimit({
  windowMs:        config.rateLimit.windowMs,
  max:             config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: "Too many requests. Please slow down." },
});
'@ | Set-Content "$base\src\api\middleware\rateLimiter.js" -Encoding UTF8

# ─── src/api/middleware/requestLogger.js ──────────────────────────────────────
@'
/**
 * requestLogger.js — Attaches a unique request ID for log tracing.
 */
const { randomUUID } = require("crypto");
const logger         = require("../../config/logger");

module.exports = function requestLogger(req, res, next) {
  req.requestId = randomUUID();
  res.setHeader("X-Request-Id", req.requestId);

  res.on("finish", () => {
    logger.debug("Request completed", {
      requestId: req.requestId,
      method:    req.method,
      path:      req.path,
      status:    res.statusCode,
      ms:        Date.now() - req._startTime,
    });
  });

  req._startTime = Date.now();
  next();
};
'@ | Set-Content "$base\src\api\middleware\requestLogger.js" -Encoding UTF8

Write-Host "[6/15] middleware written." -ForegroundColor Cyan

# ─── src/api/validators/problem.validator.js ──────────────────────────────────
@'
/**
 * problem.validator.js — Joi schema for problem analysis requests.
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
'@ | Set-Content "$base\src\api\validators\problem.validator.js" -Encoding UTF8

Write-Host "[7/15] validator written." -ForegroundColor Cyan

# ─── src/services/ai/aiClient.js ──────────────────────────────────────────────
@'
/**
 * aiClient.js — Low-level HTTP adapter for the AI microservice.
 * The only file that knows the AI service wire protocol.
 */
const axios    = require("axios");
const config   = require("../../config");
const logger   = require("../../config/logger");
const AppError = require("../../utils/AppError");

const client = axios.create({
  baseURL: config.aiService.url,
  timeout: config.aiService.timeoutMs,
  headers: {
    "Content-Type": "application/json",
    ...(config.aiService.apiKey
      ? { Authorization: `Bearer ${config.aiService.apiKey}` }
      : {}),
  },
});

client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.code === "ECONNREFUSED" || error.code === "ENOTFOUND") {
      logger.error("AI service unreachable", { code: error.code, url: config.aiService.url });
      throw new AppError("AI service is currently unavailable.", 503);
    }
    if (error.code === "ECONNABORTED" || error.message?.includes("timeout")) {
      logger.warn("AI service timed out", { timeoutMs: config.aiService.timeoutMs });
      throw new AppError("AI service timed out. Please try again.", 504);
    }
    const status  = error.response?.status  ?? 500;
    const message = error.response?.data?.error ?? "AI service returned an error.";
    logger.error("AI service error response", { status, message });
    throw new AppError(message, status);
  }
);

async function requestHints(problemData) {
  const { data } = await client.post("/hints", { problem: problemData });
  return data.hints;
}

module.exports = { requestHints };
'@ | Set-Content "$base\src\services\ai\aiClient.js" -Encoding UTF8

# ─── src/services/ai/aiService.js ─────────────────────────────────────────────
@'
/**
 * aiService.js — AI business logic layer.
 * Calls the AI client, validates the response, falls back gracefully.
 */
const aiClient = require("./aiClient");
const logger   = require("../../config/logger");

function buildFallbackHints(title) {
  return [
    `Think about which data structure gives you the best time complexity for this problem. What property must hold at every step?`,
    `Consider whether sorting the input or using a specific traversal order reveals a pattern. Can you reduce "${title}" to a simpler known subproblem?`,
    `A two-pointer or sliding window approach often achieves O(n) for this class of problem. Define the invariant your window must maintain, then determine when to expand or shrink it.`,
  ];
}

function isValidHintResponse(hints) {
  return (
    Array.isArray(hints) &&
    hints.length === 3 &&
    hints.every((h) => typeof h === "string" && h.trim().length > 0)
  );
}

async function getHints(problem) {
  try {
    const hints = await aiClient.requestHints(problem);
    if (!isValidHintResponse(hints)) {
      logger.warn("AI service returned unexpected hint shape — using fallback", { hints });
      return buildFallbackHints(problem.title);
    }
    return hints;
  } catch (err) {
    logger.warn("AI hint fetch failed — using fallback hints", {
      error: err.message,
      title: problem.title,
    });
    return buildFallbackHints(problem.title);
  }
}

module.exports = { getHints };
'@ | Set-Content "$base\src\services\ai\aiService.js" -Encoding UTF8

Write-Host "[8/15] AI service files written." -ForegroundColor Cyan

# ─── src/services/recommender/index.js ───────────────────────────────────────
@'
/**
 * recommender/index.js — Tag-weighted Jaccard similarity recommender.
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
'@ | Set-Content "$base\src\services\recommender\index.js" -Encoding UTF8

# ─── src/services/problemService.js ──────────────────────────────────────────
@'
/**
 * problemService.js — Orchestrates AI hints + recommendations in parallel.
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
'@ | Set-Content "$base\src\services\problemService.js" -Encoding UTF8

Write-Host "[9/15] recommender + problemService written." -ForegroundColor Cyan

# ─── src/api/controllers/problem.controller.js ────────────────────────────────
@'
/**
 * problem.controller.js — Handles POST /api/problem/analyze.
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
'@ | Set-Content "$base\src\api\controllers\problem.controller.js" -Encoding UTF8

# ─── src/api/controllers/health.controller.js ─────────────────────────────────
@'
/**
 * health.controller.js — GET /api/health
 */
const { ok }   = require("../../utils/respond");
const config   = require("../../config");

function getHealth(req, res) {
  return ok(res, {
    status:    "ok",
    env:       config.env,
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
}

module.exports = { getHealth };
'@ | Set-Content "$base\src\api\controllers\health.controller.js" -Encoding UTF8

Write-Host "[10/15] controllers written." -ForegroundColor Cyan

# ─── src/api/routes/health.routes.js ─────────────────────────────────────────
@'
const { Router }    = require("express");
const { getHealth } = require("../controllers/health.controller");

const router = Router();
router.get("/health", getHealth);
module.exports = router;
'@ | Set-Content "$base\src\api\routes\health.routes.js" -Encoding UTF8

# ─── src/api/routes/problem.routes.js ────────────────────────────────────────
@'
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
'@ | Set-Content "$base\src\api\routes\problem.routes.js" -Encoding UTF8

# ─── src/api/routes/index.js ─────────────────────────────────────────────────
@'
/**
 * routes/index.js — Aggregates all route modules.
 */
const { Router }    = require("express");
const requestLogger = require("../middleware/requestLogger");
const healthRoutes  = require("./health.routes");
const problemRoutes = require("./problem.routes");

const router = Router();
router.use(requestLogger);
router.use(healthRoutes);
router.use(problemRoutes);

module.exports = router;
'@ | Set-Content "$base\src\api\routes\index.js" -Encoding UTF8

Write-Host "[11/15] routes written." -ForegroundColor Cyan

# ─── src/data/problems.js ─────────────────────────────────────────────────────
@'
/**
 * problems.js — Curated mock problem dataset for the recommender.
 */
const PROBLEMS = [
  { id: 1,   title: "Two Sum",                                        slug: "two-sum",                                        difficulty: "Easy",   tags: ["Array","Hash Table"],                                                                          link: "https://leetcode.com/problems/two-sum/",                                        keywords: ["sum","pair","complement","hash","array"] },
  { id: 3,   title: "Longest Substring Without Repeating Characters", slug: "longest-substring-without-repeating-characters", difficulty: "Medium", tags: ["Hash Table","String","Sliding Window"],                                                         link: "https://leetcode.com/problems/longest-substring-without-repeating-characters/", keywords: ["substring","sliding window","window","string","unique","repeat"] },
  { id: 15,  title: "3Sum",                                           slug: "3sum",                                           difficulty: "Medium", tags: ["Array","Two Pointers","Sorting"],                                                               link: "https://leetcode.com/problems/3sum/",                                           keywords: ["sum","triplet","two pointers","sort","array"] },
  { id: 20,  title: "Valid Parentheses",                              slug: "valid-parentheses",                              difficulty: "Easy",   tags: ["String","Stack"],                                                                               link: "https://leetcode.com/problems/valid-parentheses/",                              keywords: ["parentheses","bracket","stack","valid","balance"] },
  { id: 21,  title: "Merge Two Sorted Lists",                         slug: "merge-two-sorted-lists",                         difficulty: "Easy",   tags: ["Linked List","Recursion"],                                                                      link: "https://leetcode.com/problems/merge-two-sorted-lists/",                         keywords: ["merge","linked list","sorted","recursion"] },
  { id: 33,  title: "Search in Rotated Sorted Array",                 slug: "search-in-rotated-sorted-array",                 difficulty: "Medium", tags: ["Array","Binary Search"],                                                                        link: "https://leetcode.com/problems/search-in-rotated-sorted-array/",                 keywords: ["binary search","rotated","sorted","array","search"] },
  { id: 42,  title: "Trapping Rain Water",                            slug: "trapping-rain-water",                            difficulty: "Hard",   tags: ["Array","Two Pointers","Dynamic Programming","Stack","Monotonic Stack"],                         link: "https://leetcode.com/problems/trapping-rain-water/",                            keywords: ["rain water","trap","two pointers","stack","dp","height"] },
  { id: 46,  title: "Permutations",                                   slug: "permutations",                                   difficulty: "Medium", tags: ["Array","Backtracking"],                                                                         link: "https://leetcode.com/problems/permutations/",                                   keywords: ["permutation","backtrack","recursion","combination"] },
  { id: 53,  title: "Maximum Subarray",                               slug: "maximum-subarray",                               difficulty: "Medium", tags: ["Array","Divide and Conquer","Dynamic Programming"],                                             link: "https://leetcode.com/problems/maximum-subarray/",                               keywords: ["subarray","kadane","maximum","sum","dp"] },
  { id: 70,  title: "Climbing Stairs",                                slug: "climbing-stairs",                                difficulty: "Easy",   tags: ["Math","Dynamic Programming","Memoization"],                                                     link: "https://leetcode.com/problems/climbing-stairs/",                                keywords: ["stairs","fibonacci","dp","memoization","ways"] },
  { id: 76,  title: "Minimum Window Substring",                       slug: "minimum-window-substring",                       difficulty: "Hard",   tags: ["Hash Table","String","Sliding Window"],                                                         link: "https://leetcode.com/problems/minimum-window-substring/",                       keywords: ["window","minimum","substring","sliding window","string","hash"] },
  { id: 98,  title: "Validate Binary Search Tree",                    slug: "validate-binary-search-tree",                    difficulty: "Medium", tags: ["Tree","Depth-First Search","Binary Search Tree","Binary Tree"],                                 link: "https://leetcode.com/problems/validate-binary-search-tree/",                    keywords: ["bst","validate","binary search tree","inorder","dfs"] },
  { id: 102, title: "Binary Tree Level Order Traversal",              slug: "binary-tree-level-order-traversal",              difficulty: "Medium", tags: ["Tree","Breadth-First Search","Binary Tree"],                                                    link: "https://leetcode.com/problems/binary-tree-level-order-traversal/",              keywords: ["bfs","level order","binary tree","queue","traversal"] },
  { id: 121, title: "Best Time to Buy and Sell Stock",                slug: "best-time-to-buy-and-sell-stock",                difficulty: "Easy",   tags: ["Array","Dynamic Programming"],                                                                  link: "https://leetcode.com/problems/best-time-to-buy-and-sell-stock/",                keywords: ["stock","profit","buy","sell","max","array"] },
  { id: 128, title: "Longest Consecutive Sequence",                   slug: "longest-consecutive-sequence",                   difficulty: "Medium", tags: ["Array","Hash Table","Union Find"],                                                               link: "https://leetcode.com/problems/longest-consecutive-sequence/",                   keywords: ["consecutive","sequence","hash set","array","longest"] },
  { id: 141, title: "Linked List Cycle",                              slug: "linked-list-cycle",                              difficulty: "Easy",   tags: ["Hash Table","Linked List","Two Pointers"],                                                      link: "https://leetcode.com/problems/linked-list-cycle/",                              keywords: ["cycle","linked list","floyd","two pointers","fast slow"] },
  { id: 152, title: "Maximum Product Subarray",                       slug: "maximum-product-subarray",                       difficulty: "Medium", tags: ["Array","Dynamic Programming"],                                                                  link: "https://leetcode.com/problems/maximum-product-subarray/",                       keywords: ["product","subarray","maximum","dp","negative"] },
  { id: 200, title: "Number of Islands",                              slug: "number-of-islands",                              difficulty: "Medium", tags: ["Array","Depth-First Search","Breadth-First Search","Union Find","Matrix"],                      link: "https://leetcode.com/problems/number-of-islands/",                              keywords: ["island","dfs","bfs","grid","matrix","flood fill"] },
  { id: 206, title: "Reverse Linked List",                            slug: "reverse-linked-list",                            difficulty: "Easy",   tags: ["Linked List","Recursion"],                                                                      link: "https://leetcode.com/problems/reverse-linked-list/",                            keywords: ["reverse","linked list","recursion","iterative"] },
  { id: 217, title: "Contains Duplicate",                             slug: "contains-duplicate",                             difficulty: "Easy",   tags: ["Array","Hash Table","Sorting"],                                                                 link: "https://leetcode.com/problems/contains-duplicate/",                             keywords: ["duplicate","hash","set","array","unique"] },
  { id: 226, title: "Invert Binary Tree",                             slug: "invert-binary-tree",                             difficulty: "Easy",   tags: ["Tree","Depth-First Search","Breadth-First Search","Binary Tree"],                              link: "https://leetcode.com/problems/invert-binary-tree/",                             keywords: ["invert","mirror","binary tree","recursion","dfs"] },
  { id: 238, title: "Product of Array Except Self",                   slug: "product-of-array-except-self",                   difficulty: "Medium", tags: ["Array","Prefix Sum"],                                                                           link: "https://leetcode.com/problems/product-of-array-except-self/",                   keywords: ["product","prefix","suffix","array","no division"] },
  { id: 242, title: "Valid Anagram",                                  slug: "valid-anagram",                                  difficulty: "Easy",   tags: ["Hash Table","String","Sorting"],                                                                link: "https://leetcode.com/problems/valid-anagram/",                                  keywords: ["anagram","hash","frequency","string","sort"] },
  { id: 300, title: "Longest Increasing Subsequence",                 slug: "longest-increasing-subsequence",                 difficulty: "Medium", tags: ["Array","Binary Search","Dynamic Programming"],                                                  link: "https://leetcode.com/problems/longest-increasing-subsequence/",                 keywords: ["lis","increasing","subsequence","dp","binary search"] },
  { id: 322, title: "Coin Change",                                    slug: "coin-change",                                    difficulty: "Medium", tags: ["Array","Dynamic Programming","Breadth-First Search"],                                           link: "https://leetcode.com/problems/coin-change/",                                    keywords: ["coin","change","dp","minimum","bfs","greedy"] },
  { id: 338, title: "Counting Bits",                                  slug: "counting-bits",                                  difficulty: "Easy",   tags: ["Dynamic Programming","Bit Manipulation"],                                                       link: "https://leetcode.com/problems/counting-bits/",                                  keywords: ["bits","count","dp","bit manipulation","binary"] },
  { id: 347, title: "Top K Frequent Elements",                        slug: "top-k-frequent-elements",                        difficulty: "Medium", tags: ["Array","Hash Table","Sorting","Heap (Priority Queue)","Bucket Sort"],                          link: "https://leetcode.com/problems/top-k-frequent-elements/",                        keywords: ["top k","frequency","heap","bucket sort","hash"] },
  { id: 417, title: "Pacific Atlantic Water Flow",                    slug: "pacific-atlantic-water-flow",                    difficulty: "Medium", tags: ["Array","Depth-First Search","Breadth-First Search","Matrix"],                                  link: "https://leetcode.com/problems/pacific-atlantic-water-flow/",                    keywords: ["pacific","atlantic","dfs","bfs","grid","flow","matrix"] },
  { id: 572, title: "Subtree of Another Tree",                        slug: "subtree-of-another-tree",                        difficulty: "Easy",   tags: ["Tree","Depth-First Search","String Matching","Binary Tree","Hash Function"],                   link: "https://leetcode.com/problems/subtree-of-another-tree/",                        keywords: ["subtree","binary tree","dfs","match","recursion"] },
  { id: 647, title: "Palindromic Substrings",                         slug: "palindromic-substrings",                         difficulty: "Medium", tags: ["String","Dynamic Programming"],                                                                 link: "https://leetcode.com/problems/palindromic-substrings/",                         keywords: ["palindrome","substring","dp","expand","string"] },
];

module.exports = PROBLEMS;
'@ | Set-Content "$base\src\data\problems.js" -Encoding UTF8

Write-Host "[12/15] data/problems.js written." -ForegroundColor Cyan

# ─── tests/recommender.test.js ────────────────────────────────────────────────
@'
const { getSimilarProblems, scoreCandidate } = require("../src/services/recommender");

describe("Recommender — getSimilarProblems", () => {
  it("returns up to 5 results by default", () => {
    const results = getSimilarProblems({ title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"] });
    expect(results.length).toBeLessThanOrEqual(5);
    expect(results.length).toBeGreaterThan(0);
  });

  it("excludes the exact queried problem by title", () => {
    const results = getSimilarProblems({ title: "Two Sum", difficulty: "Easy", tags: ["Array"] });
    expect(results.find((r) => r.title === "Two Sum")).toBeUndefined();
  });

  it("each result has title, difficulty, and link", () => {
    const results = getSimilarProblems({ title: "Coin Change", difficulty: "Medium", tags: ["Dynamic Programming"] });
    results.forEach((r) => {
      expect(r).toHaveProperty("title");
      expect(r).toHaveProperty("difficulty");
      expect(r).toHaveProperty("link");
    });
  });

  it("returns results even with no tags provided", () => {
    const results = getSimilarProblems({ title: "Number of Islands", difficulty: "Medium", tags: [] });
    expect(results.length).toBeGreaterThan(0);
  });

  it("respects custom limit", () => {
    const results = getSimilarProblems({ title: "3Sum", difficulty: "Medium", tags: ["Array"] }, 3);
    expect(results.length).toBeLessThanOrEqual(3);
  });
});

describe("Recommender — scoreCandidate", () => {
  it("scores high tag overlap above low tag overlap", () => {
    const query     = { title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"] };
    const highMatch = { title: "Contains Duplicate", difficulty: "Easy",   tags: ["Array","Hash Table"], keywords: ["duplicate","hash"], link: "" };
    const lowMatch  = { title: "Trapping Rain Water", difficulty: "Hard",  tags: ["Stack","Monotonic Stack"], keywords: ["rain","trap"],  link: "" };
    expect(scoreCandidate(query, highMatch)).toBeGreaterThan(scoreCandidate(query, lowMatch));
  });
});
'@ | Set-Content "$base\tests\recommender.test.js" -Encoding UTF8

# ─── tests/problem.controller.test.js ────────────────────────────────────────
@'
const request = require("supertest");
const app     = require("../src/app");

jest.mock("../src/services/ai/aiService", () => ({
  getHints: jest.fn().mockResolvedValue([
    "Hint level 1 — vague",
    "Hint level 2 — directional",
    "Hint level 3 — algorithmic",
  ]),
}));

describe("POST /api/problem/analyze", () => {
  const ENDPOINT = "/api/problem/analyze";

  it("returns 200 with a well-formed payload", async () => {
    const res = await request(app).post(ENDPOINT).send({
      title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"],
    });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.problemTitle).toBe("Two Sum");
    expect(res.body.data.hintLevels).toHaveLength(3);
    expect(res.body.data.similarProblems.length).toBeGreaterThan(0);
  });

  it("returns 400 when title is missing", async () => {
    const res = await request(app).post(ENDPOINT).send({ difficulty: "Easy" });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/title/i);
  });

  it("returns 400 when title is too short", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "A" });
    expect(res.status).toBe(400);
  });

  it("accepts optional fields gracefully", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "Valid Parentheses" });
    expect(res.status).toBe(200);
    expect(res.body.data.hintLevels).toHaveLength(3);
  });

  it("strips unknown fields silently", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "3Sum", unknownField: "ignored" });
    expect(res.status).toBe(200);
  });
});

describe("GET /api/health", () => {
  it("returns 200 with status ok", async () => {
    const res = await request(app).get("/api/health");
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("ok");
  });
});
'@ | Set-Content "$base\tests\problem.controller.test.js" -Encoding UTF8

Write-Host "[13/15] tests written." -ForegroundColor Cyan

# ─── jest.config.js ───────────────────────────────────────────────────────────
@'
module.exports = {
  testEnvironment: "node",
  testMatch: ["**/tests/**/*.test.js"],
  collectCoverageFrom: ["src/**/*.js"],
};
'@ | Set-Content "$base\jest.config.js" -Encoding UTF8

Write-Host "[14/15] jest.config.js written." -ForegroundColor Cyan

# ─── Copy .env.example to .env ────────────────────────────────────────────────
Copy-Item "$base\.env.example" "$base\.env" -Force
Write-Host "[15/15] .env created from .env.example." -ForegroundColor Cyan

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  LeetTow backend scaffold complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. cd $base" -ForegroundColor White
Write-Host "  2. npm install" -ForegroundColor White
Write-Host "  3. Edit .env (set AI_SERVICE_URL, PORT, etc.)" -ForegroundColor White
Write-Host "  4. npm run dev        <- development server with hot reload" -ForegroundColor White
Write-Host "  5. npm test           <- run all tests" -ForegroundColor White
Write-Host ""
Write-Host "Endpoints:" -ForegroundColor Yellow
Write-Host "  POST http://localhost:3001/api/problem/analyze" -ForegroundColor White
Write-Host "  GET  http://localhost:3001/api/health" -ForegroundColor White
Write-Host ""
