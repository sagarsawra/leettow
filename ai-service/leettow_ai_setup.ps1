# leettow_ai_setup.ps1
# Creates the complete LeetTow AI Service
# Usage: .\leettow_ai_setup.ps1

$base = "C:\Users\lenovo\Documents\GitHub\leettow\ai-service"

# ── Create folders ────────────────────────────────────────────────────────────
$folders = @(
    "$base\src\config",
    "$base\src\prompts",
    "$base\src\services",
    "$base\src\utils",
    "$base\src\api\validators",
    "$base\src\api\middleware",
    "$base\src\api\controllers",
    "$base\src\api\routes",
    "$base\tests"
)
foreach ($f in $folders) { New-Item -ItemType Directory -Force -Path $f | Out-Null }
Write-Host "Folders created." -ForegroundColor Cyan

# ── Helper ────────────────────────────────────────────────────────────────────
function Write-File($path, $content) {
    Set-Content -Path $path -Value $content -Encoding UTF8 -Force
    Write-Host "  [+] $path" -ForegroundColor DarkGray
}

# =============================================================================
# ROOT FILES
# =============================================================================

Write-File "$base\package.json" @'
{
  "name": "leettow-ai-service",
  "version": "1.0.0",
  "description": "LeetTow AI microservice — generates structured, no-spoiler hints for coding problems",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest --runInBand --forceExit"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.18.3",
    "express-rate-limit": "^7.2.0",
    "helmet": "^7.1.0",
    "joi": "^17.12.2",
    "morgan": "^1.10.0",
    "openai": "^4.28.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "nodemon": "^3.1.0",
    "supertest": "^6.3.4"
  }
}
'@

Write-File "$base\.env.example" @'
# Server
PORT=5000
NODE_ENV=development

# OpenAI
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o
OPENAI_TIMEOUT_MS=15000
OPENAI_MAX_TOKENS=600
OPENAI_TEMPERATURE=0.4

# Rate limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=20

# Allowed callers (comma-separated origins)
ALLOWED_ORIGINS=http://localhost:3001
'@

Write-File "$base\.gitignore" @'
node_modules/
.env
*.log
coverage/
'@

Write-File "$base\jest.config.js" @'
module.exports = {
  testEnvironment: "node",
  testMatch: ["**/tests/**/*.test.js"],
  collectCoverageFrom: ["src/**/*.js"],
};
'@

# =============================================================================
# CONFIG
# =============================================================================

Write-File "$base\src\config\index.js" @'
/**
 * config/index.js — Single source of runtime configuration.
 * Validates critical values at startup so misconfiguration fails loudly.
 */
require("dotenv").config();

function required(key) {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required environment variable: ${key}`);
  return val;
}

function optional(key, fallback) {
  return process.env[key] || fallback;
}

const config = {
  env:  optional("NODE_ENV", "development"),
  port: parseInt(optional("PORT", "5000"), 10),

  openai: {
    apiKey:      required("OPENAI_API_KEY"),
    model:       optional("OPENAI_MODEL", "gpt-4o"),
    timeoutMs:   parseInt(optional("OPENAI_TIMEOUT_MS", "15000"), 10),
    maxTokens:   parseInt(optional("OPENAI_MAX_TOKENS", "600"), 10),
    temperature: parseFloat(optional("OPENAI_TEMPERATURE", "0.4")),
  },

  rateLimit: {
    windowMs: parseInt(optional("RATE_LIMIT_WINDOW_MS", "60000"), 10),
    max:      parseInt(optional("RATE_LIMIT_MAX", "20"), 10),
  },

  cors: {
    allowedOrigins: optional("ALLOWED_ORIGINS", "http://localhost:3001")
      .split(",")
      .map((o) => o.trim())
      .filter(Boolean),
  },
};

module.exports = config;
'@

Write-File "$base\src\config\logger.js" @'
/**
 * config/logger.js — Structured JSON logger.
 * Drop-in replaceable with Winston/Pino without changing callers.
 */
const config = require("./index");

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };
const active = config.env === "production" ? LEVELS.info : LEVELS.debug;

function log(level, message, meta = {}) {
  if (LEVELS[level] > active) return;
  const line = JSON.stringify({
    ts:      new Date().toISOString(),
    service: "leettow-ai",
    level,
    message,
    ...(Object.keys(meta).length ? { meta } : {}),
  });
  level === "error" ? console.error(line) : console.log(line);
}

module.exports = {
  error: (msg, meta) => log("error", msg, meta),
  warn:  (msg, meta) => log("warn",  msg, meta),
  info:  (msg, meta) => log("info",  msg, meta),
  debug: (msg, meta) => log("debug", msg, meta),
};
'@

# =============================================================================
# PROMPTS
# =============================================================================

Write-File "$base\src\prompts\systemPrompt.js" @'
/**
 * systemPrompt.js — The behavioral contract for the LLM.
 *
 * Design philosophy:
 *   The system prompt is a CONSTITUTION, not a description.
 *   Constraints are stated in absolute terms because fuzzy language
 *   produces fuzzy compliance. Temperature is kept low (0.4) to reduce
 *   hallucination, but this prompt is the primary guard against solution leakage.
 */

const SYSTEM_PROMPT = `
You are LeetTow Hint Engine — an AI tutor embedded inside a coding assistant.
Your only job is to generate exactly 3 progressive, Socratic hints for a coding problem.

IDENTITY RULES (never break these):
- You are a tutor, not a solver. You guide thinking; you never provide answers.
- You speak to a developer who is stuck but capable. Treat them as an intelligent adult.
- You operate inside a Chrome extension; responses must be concise and scannable.

OUTPUT CONTRACT (strictly enforced):
- Return ONLY a valid JSON object. No markdown, no prose, no code fences.
- The JSON must have exactly one key: "hintLevels"
- "hintLevels" must be an array of exactly 3 strings.
- Each string is one hint. No sub-arrays, no nested objects.
- Example structure: {"hintLevels": ["...", "...", "..."]}

HINT LEVEL DEFINITIONS:
Level 1 — Intuition Seed:
  - One or two sentences maximum.
  - Ask a guiding question or offer a high-level observation.
  - ZERO technical vocabulary (no algorithm names, no data structure names).
  - Goal: make the developer pause and think about the problem differently.

Level 2 — Direction Nudge:
  - Two to three sentences.
  - Suggest an approach pattern without naming it explicitly.
  - You may use generic terms (e.g., "a structure that gives fast lookups")
    but not specific names (e.g., "HashMap", "binary search").
  - Goal: guide the developer toward the right category of solution.

Level 3 — Path Illuminator:
  - Three to four sentences.
  - Clearly describe the solution strategy in concrete but non-naming terms.
  - You may describe WHAT the algorithm does but not WHAT it is called.
  - You may hint at time complexity implications.
  - Goal: the developer should be able to implement from this hint alone,
    without being given the answer.

ABSOLUTE PROHIBITIONS (if you violate any of these, the response is invalid):
- Never write or imply code, pseudocode, or syntax.
- Never name a specific algorithm (e.g., "Kadane's", "Floyd's", "Dijkstra's").
- Never name a specific data structure by its canonical name (e.g., "HashMap", "monotonic stack").
- Never state the final answer or the core insight directly.
- Never produce markdown, backticks, or any formatting outside the JSON envelope.
- Never add explanation, commentary, or apology outside the JSON.
- Never produce fewer or more than exactly 3 hints.
- Never repeat the same core idea across hint levels — each level must add new information.

TONE RULES:
- Be concise. Developers are impatient.
- Use active voice. Avoid passive constructions.
- Sound like a senior engineer mentoring, not a textbook explaining.
- Hints should feel like a nudge from a colleague, not a lecture.
`.trim();

module.exports = SYSTEM_PROMPT;
'@

Write-File "$base\src\prompts\userPrompt.js" @'
/**
 * userPrompt.js — Formats the incoming problem data into a structured prompt.
 *
 * Design decisions:
 *   1. The user prompt is kept minimal — the system prompt carries the rules.
 *   2. Fields are explicitly labelled so the model can extract them reliably.
 *   3. Unknown difficulty is sent as "Not specified" rather than "Unknown"
 *      because "Unknown" can confuse some models into treating it as valid data.
 *   4. Description is truncated to prevent token overflow while preserving
 *      the most relevant context (first 800 chars is usually the problem statement).
 */

const MAX_DESCRIPTION_LENGTH = 800;

/**
 * Build the user turn for the hint generation request.
 * @param {{ title: string, description?: string, difficulty?: string }} problem
 * @returns {string}
 */
function buildUserPrompt(problem) {
  const title       = problem.title.trim();
  const difficulty  = problem.difficulty?.trim() || "Not specified";
  const description = problem.description
    ? problem.description.trim().slice(0, MAX_DESCRIPTION_LENGTH)
    : "Not provided";

  return `
Generate 3 progressive hints for the following coding problem.
Follow all rules from your system instructions exactly.

PROBLEM TITLE: ${title}
DIFFICULTY: ${difficulty}
DESCRIPTION: ${description}

Return ONLY the JSON object. No other text.
`.trim();
}

module.exports = { buildUserPrompt };
'@

# =============================================================================
# SERVICES
# =============================================================================

Write-File "$base\src\services\openaiClient.js" @'
/**
 * openaiClient.js — Low-level OpenAI API adapter.
 *
 * This is the ONLY file that imports and calls the OpenAI SDK.
 * Swapping to Anthropic, Gemini, or a self-hosted model requires
 * changing only this file — nothing else in the service changes.
 *
 * Design decisions:
 *   - Uses response_format: { type: "json_object" } to enforce JSON output
 *     at the API level, not just via prompting. Belt AND suspenders.
 *   - AbortController handles the timeout so the HTTP connection is actually
 *     severed — not just ignored — when the limit is hit.
 *   - The client is a singleton; re-instantiating on every request is wasteful.
 */
const OpenAI   = require("openai");
const config   = require("../config");
const logger   = require("../config/logger");
const AppError = require("../utils/AppError");

// Singleton OpenAI client.
const openai = new OpenAI({ apiKey: config.openai.apiKey });

/**
 * Call the OpenAI chat completions API with a system + user prompt pair.
 * @param {string} systemPrompt
 * @param {string} userPrompt
 * @returns {Promise<string>} Raw response content from the model.
 */
async function callOpenAI(systemPrompt, userPrompt) {
  const controller = new AbortController();
  const timeoutId  = setTimeout(() => controller.abort(), config.openai.timeoutMs);

  try {
    logger.debug("Calling OpenAI", { model: config.openai.model });

    const response = await openai.chat.completions.create(
      {
        model:           config.openai.model,
        temperature:     config.openai.temperature,
        max_tokens:      config.openai.maxTokens,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user",   content: userPrompt   },
        ],
      },
      { signal: controller.signal }
    );

    const content = response.choices?.[0]?.message?.content;

    if (!content) {
      throw new AppError("OpenAI returned an empty response.", 502);
    }

    logger.debug("OpenAI response received", {
      model:            response.model,
      promptTokens:     response.usage?.prompt_tokens,
      completionTokens: response.usage?.completion_tokens,
      finishReason:     response.choices?.[0]?.finish_reason,
    });

    return content;

  } catch (err) {
    if (err.name === "AbortError" || err.code === "ERR_CANCELED") {
      logger.warn("OpenAI request timed out", { timeoutMs: config.openai.timeoutMs });
      throw new AppError("AI request timed out.", 504);
    }

    if (err?.status) {
      const msg = err.message || "OpenAI API error";
      logger.error("OpenAI API error", { status: err.status, message: msg });
      throw new AppError(msg, err.status >= 500 ? 502 : err.status);
    }

    if (err.name === "AppError") throw err;

    logger.error("Unexpected OpenAI client error", { message: err.message });
    throw new AppError("AI service error. Please try again.", 502);

  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = { callOpenAI };
'@

Write-File "$base\src\services\hintParser.js" @'
/**
 * hintParser.js — Parses and validates the raw LLM response.
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
'@

Write-File "$base\src\services\fallbackHints.js" @'
/**
 * fallbackHints.js — Deterministic difficulty-aware fallback hints.
 *
 * Used when the LLM call fails, times out, or returns unparseable output.
 * A degraded-but-functional response is always better than an error
 * from the user's perspective.
 */

const FALLBACKS = {
  Easy: [
    "Consider what information you already have and what you need to find. Is there a simple relationship between them?",
    "Think about what structure would let you store and retrieve information efficiently as you scan through the input.",
    "A single pass through the data is likely sufficient. As you iterate, think about what state you need to track at each step to avoid redundant work.",
  ],
  Medium: [
    "Step back from the details. What is the core decision this problem is asking you to make at each step?",
    "Consider whether pre-processing the input — sorting it, indexing it, or transforming it — changes what operations become cheap versus expensive.",
    "Think about the trade-off between time and space. Accepting extra memory often unlocks a significantly faster traversal strategy. What would you store, and when would you look it up?",
  ],
  Hard: [
    "Hard problems are usually combinations of simpler subproblems. Can you decompose this into two or three problems you already know how to solve?",
    "Consider whether you are solving the same subproblem multiple times. If so, there is likely a way to store intermediate results to avoid recomputation.",
    "Think about the problem in reverse, or from the perspective of the optimal answer. What properties must a valid solution have, and can you build toward those properties incrementally?",
  ],
};

const DEFAULT_FALLBACK = FALLBACKS.Medium;

/**
 * Get fallback hints for a given difficulty level.
 * @param {string} [difficulty] "Easy" | "Medium" | "Hard"
 * @returns {string[]} Array of exactly 3 hint strings.
 */
function getFallbackHints(difficulty) {
  return FALLBACKS[difficulty] ?? DEFAULT_FALLBACK;
}

module.exports = { getFallbackHints };
'@

Write-File "$base\src\services\hintService.js" @'
/**
 * hintService.js — Orchestrates the full hint generation flow.
 *
 * Flow:
 *   1. Build system + user prompts.
 *   2. Call OpenAI via the client adapter.
 *   3. Parse and validate the response.
 *   4. If parsing fails, retry ONCE (models occasionally produce malformed output).
 *   5. If retry also fails, degrade to difficulty-aware fallback hints.
 *   6. If the AI call itself throws, degrade immediately to fallback.
 *
 * The caller (controller) always receives { hintLevels: string[] } — never an error
 * caused by an AI failure. Failures are logged for observability but hidden from clients.
 *
 * Why one retry?
 *   A single retry on parse failure catches transient LLM formatting errors without
 *   significantly increasing latency or cost. Two retries would double worst-case cost.
 */
const SYSTEM_PROMPT         = require("../prompts/systemPrompt");
const { buildUserPrompt }   = require("../prompts/userPrompt");
const { callOpenAI }        = require("./openaiClient");
const { parseHintResponse } = require("./hintParser");
const { getFallbackHints }  = require("./fallbackHints");
const logger                = require("../config/logger");

const MAX_RETRIES = 1;

/**
 * Generate structured hints for a coding problem.
 * @param {{ title: string, description?: string, difficulty?: string }} problem
 * @returns {Promise<{ hintLevels: string[] }>}
 */
async function generateHints(problem) {
  const userPrompt = buildUserPrompt(problem);
  let attempts = 0;

  while (attempts <= MAX_RETRIES) {
    attempts++;

    try {
      logger.info("Generating hints", {
        title:      problem.title,
        difficulty: problem.difficulty,
        attempt:    attempts,
      });

      const rawContent = await callOpenAI(SYSTEM_PROMPT, userPrompt);
      const { valid, hints, reason } = parseHintResponse(rawContent);

      if (valid) {
        logger.info("Hints generated successfully", { title: problem.title, attempt: attempts });
        return { hintLevels: hints };
      }

      logger.warn("Hint parsing failed", { reason, attempt: attempts, willRetry: attempts <= MAX_RETRIES });

    } catch (err) {
      logger.error("AI call failed — using fallback", {
        title:   problem.title,
        message: err.message,
        status:  err.statusCode,
      });
      break;
    }
  }

  logger.warn("Returning fallback hints", { title: problem.title, difficulty: problem.difficulty });
  return { hintLevels: getFallbackHints(problem.difficulty) };
}

module.exports = { generateHints };
'@

# =============================================================================
# UTILS
# =============================================================================

Write-File "$base\src\utils\AppError.js" @'
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
'@

Write-File "$base\src\utils\asyncHandler.js" @'
/**
 * asyncHandler.js — Forwards async rejections to Express next(err).
 */
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
module.exports = asyncHandler;
'@

Write-File "$base\src\utils\respond.js" @'
/**
 * respond.js — Consistent API response envelope.
 */
function ok(res, data, status = 200) {
  return res.status(status).json({ success: true, data });
}
function fail(res, message, status = 500) {
  return res.status(status).json({ success: false, error: message });
}
module.exports = { ok, fail };
'@

# =============================================================================
# API — VALIDATORS
# =============================================================================

Write-File "$base\src\api\validators\hint.validator.js" @'
/**
 * hint.validator.js — Joi schema for POST /generate-hint requests.
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
'@

# =============================================================================
# API — MIDDLEWARE
# =============================================================================

Write-File "$base\src\api\middleware\errorHandler.js" @'
/**
 * errorHandler.js — Centralised Express error handler.
 */
const logger   = require("../../config/logger");
const AppError = require("../../utils/AppError");
const config   = require("../../config");

// eslint-disable-next-line no-unused-vars
module.exports = function errorHandler(err, req, res, next) {
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
      ? "An unexpected error occurred."
      : err.message,
  });
};
'@

Write-File "$base\src\api\middleware\rateLimiter.js" @'
const rateLimit = require("express-rate-limit");
const config    = require("../../config");

module.exports = rateLimit({
  windowMs:        config.rateLimit.windowMs,
  max:             config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: "Too many requests. Please slow down." },
});
'@

Write-File "$base\src\api\middleware\requestLogger.js" @'
const { randomUUID } = require("crypto");
const logger         = require("../../config/logger");

module.exports = function requestLogger(req, res, next) {
  req.requestId = randomUUID();
  res.setHeader("X-Request-Id", req.requestId);
  req._startTime = Date.now();

  res.on("finish", () => {
    logger.debug("Request completed", {
      requestId: req.requestId,
      method:    req.method,
      path:      req.path,
      status:    res.statusCode,
      ms:        Date.now() - req._startTime,
    });
  });

  next();
};
'@

# =============================================================================
# API — CONTROLLERS
# =============================================================================

Write-File "$base\src\api\controllers\hint.controller.js" @'
/**
 * hint.controller.js — Handles POST /generate-hint.
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
  // AI failures degrade to fallback — they never throw to the controller.
  const result = await generateHints(value);

  return ok(res, result);
});

module.exports = { generateHint };
'@

Write-File "$base\src\api\controllers\health.controller.js" @'
const { ok } = require("../../utils/respond");
const config = require("../../config");

function getHealth(req, res) {
  return ok(res, {
    status:    "ok",
    service:   "leettow-ai-service",
    model:     config.openai.model,
    env:       config.env,
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
}

module.exports = { getHealth };
'@

# =============================================================================
# API — ROUTES
# =============================================================================

Write-File "$base\src\api\routes\hint.routes.js" @'
const { Router }       = require("express");
const { generateHint } = require("../controllers/hint.controller");

const router = Router();

/**
 * POST /generate-hint
 * Body: { title, description?, difficulty? }
 * Response: { success, data: { hintLevels: string[] } }
 */
router.post("/generate-hint", generateHint);

module.exports = router;
'@

Write-File "$base\src\api\routes\health.routes.js" @'
const { Router }    = require("express");
const { getHealth } = require("../controllers/health.controller");

const router = Router();
router.get("/health", getHealth);
module.exports = router;
'@

Write-File "$base\src\api\routes\index.js" @'
const { Router }    = require("express");
const requestLogger = require("../middleware/requestLogger");
const hintRoutes    = require("./hint.routes");
const healthRoutes  = require("./health.routes");

const router = Router();
router.use(requestLogger);
router.use(hintRoutes);
router.use(healthRoutes);
module.exports = router;
'@

# =============================================================================
# APP + SERVER
# =============================================================================

Write-File "$base\src\app.js" @'
const express      = require("express");
const helmet       = require("helmet");
const cors         = require("cors");
const morgan       = require("morgan");
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

app.use(express.json({ limit: "20kb" }));

if (config.env !== "test") {
  app.use(morgan("short"));
}

app.use(rateLimiter);
app.use(routes);

app.use((req, res) => {
  res.status(404).json({ success: false, error: "Route not found." });
});

app.use(errorHandler);

module.exports = app;
'@

Write-File "$base\src\server.js" @'
const app    = require("./app");
const config = require("./config");
const logger = require("./config/logger");

const server = app.listen(config.port, () => {
  logger.info("LeetTow AI service running", {
    port:  config.port,
    env:   config.env,
    model: config.openai.model,
  });
});

function shutdown(signal) {
  logger.info(`${signal} received — shutting down`);
  server.close(() => { logger.info("Server closed"); process.exit(0); });
  setTimeout(() => process.exit(1), 10_000);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT",  () => shutdown("SIGINT"));

process.on("unhandledRejection", (reason) => {
  logger.error("Unhandled rejection", { reason: String(reason) });
  process.exit(1);
});
'@

# =============================================================================
# TESTS
# =============================================================================

Write-File "$base\tests\hintParser.test.js" @'
const { parseHintResponse } = require("../src/services/hintParser");

describe("hintParser", () => {
  it("accepts a valid 3-hint response", () => {
    const raw = JSON.stringify({ hintLevels: [
      "Think about what you are really being asked to find here, and whether you have seen something similar before.",
      "Consider a structure that allows you to check existence of a value in constant time as you move through the input.",
      "As you iterate, for each element, check whether the value that would complete your target already exists in the structure. If not, record the current element for future lookups.",
    ]});
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(true);
    expect(result.hints).toHaveLength(3);
  });

  it("rejects non-JSON input", () => {
    const result = parseHintResponse("not json at all");
    expect(result.valid).toBe(false);
    expect(result.reason).toMatch(/JSON/i);
  });

  it("rejects wrong number of hints", () => {
    const raw = JSON.stringify({ hintLevels: ["only one hint here that is long enough to pass the length check yes"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
    expect(result.reason).toMatch(/3/);
  });

  it("rejects missing hintLevels key", () => {
    const raw = JSON.stringify({ hints: ["a", "b", "c"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
  });

  it("rejects hints that are too short", () => {
    const raw = JSON.stringify({ hintLevels: ["short", "also short", "still short"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
  });
});
'@

Write-File "$base\tests\fallbackHints.test.js" @'
const { getFallbackHints } = require("../src/services/fallbackHints");

describe("fallbackHints", () => {
  it("returns exactly 3 hints for Easy",   () => expect(getFallbackHints("Easy")).toHaveLength(3));
  it("returns exactly 3 hints for Medium", () => expect(getFallbackHints("Medium")).toHaveLength(3));
  it("returns exactly 3 hints for Hard",   () => expect(getFallbackHints("Hard")).toHaveLength(3));

  it("returns default fallback for unknown difficulty", () => {
    expect(getFallbackHints("Unknown")).toHaveLength(3);
  });

  it("each hint is a non-empty string", () => {
    getFallbackHints("Hard").forEach((h) => {
      expect(typeof h).toBe("string");
      expect(h.length).toBeGreaterThan(0);
    });
  });
});
'@

Write-File "$base\tests\hint.controller.test.js" @'
const request = require("supertest");
const app     = require("../src/app");

jest.mock("../src/services/hintService", () => ({
  generateHints: jest.fn().mockResolvedValue({
    hintLevels: [
      "Think about the core relationship between elements in this problem.",
      "Consider a structure that gives you fast lookups as you scan the input once.",
      "For each element, check whether the complement you need has already been seen. Store elements as you go.",
    ],
  }),
}));

describe("POST /generate-hint", () => {
  const ENDPOINT = "/generate-hint";

  it("returns 200 with hintLevels array for valid input", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "Two Sum", difficulty: "Easy" });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.hintLevels).toHaveLength(3);
  });

  it("returns 400 when title is missing", async () => {
    const res = await request(app).post(ENDPOINT).send({ difficulty: "Easy" });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/title/i);
  });

  it("returns 400 when title is too short", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "X" });
    expect(res.status).toBe(400);
  });

  it("accepts optional description field", async () => {
    const res = await request(app).post(ENDPOINT).send({
      title: "Longest Consecutive Sequence",
      difficulty: "Medium",
      description: "Given an unsorted array of integers...",
    });
    expect(res.status).toBe(200);
  });

  it("strips unknown fields silently", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "3Sum", unknownField: "ignored" });
    expect(res.status).toBe(200);
  });
});

describe("GET /health", () => {
  it("returns 200 with status ok", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("ok");
    expect(res.body.data.service).toBe("leettow-ai-service");
  });
});
'@

# =============================================================================
# DONE
# =============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  LeetTow AI Service scaffold complete! " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  cd $base" -ForegroundColor White
Write-Host "  npm install" -ForegroundColor White
Write-Host "  Copy-Item .env.example .env" -ForegroundColor White
Write-Host "  # Add your OPENAI_API_KEY to .env" -ForegroundColor DarkGray
Write-Host "  npm run dev      # Start dev server on :5000" -ForegroundColor White
Write-Host "  npm test         # Run tests (no real API calls)" -ForegroundColor White
Write-Host ""
Write-Host "Endpoints:" -ForegroundColor Yellow
Write-Host "  POST http://localhost:5000/generate-hint" -ForegroundColor White
Write-Host "  GET  http://localhost:5000/health" -ForegroundColor White
