/**
 * config/index.js â€” Single source of truth for runtime configuration.
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
