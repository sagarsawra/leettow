/**
 * rateLimiter.js â€” express-rate-limit configured via env vars.
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
