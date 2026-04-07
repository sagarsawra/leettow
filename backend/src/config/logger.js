/**
 * config/logger.js â€” Lightweight structured logger.
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
