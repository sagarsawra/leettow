/**
 * errorHandler.js â€” Centralised Express error handler.
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
