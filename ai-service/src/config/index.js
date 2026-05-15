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
  env: optional("NODE_ENV", "development"),
  port: parseInt(optional("PORT", "5000"), 10),

  groq: {
    apiKey: required("GROQ_API_KEY"),
    model: optional("GROQ_MODEL", "llama3-70b-8192"),
    timeoutMs: parseInt(optional("GROQ_TIMEOUT_MS", "15000"), 10),
    maxTokens: parseInt(optional("GROQ_MAX_TOKENS", "600"), 10),
    temperature: parseFloat(optional("GROQ_TEMPERATURE", "0.4")),
  },

  rateLimit: {
    windowMs: parseInt(optional("RATE_LIMIT_WINDOW_MS", "60000"), 10),
    max: parseInt(optional("RATE_LIMIT_MAX", "20"), 10),
  },

  cors: {
    allowedOrigins: optional("ALLOWED_ORIGINS", "http://localhost:3001")
      .split(",")
      .map((o) => o.trim())
      .filter(Boolean),
  },
};

module.exports = config;