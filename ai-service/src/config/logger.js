/**
 * config/logger.js â€” Structured JSON logger.
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
