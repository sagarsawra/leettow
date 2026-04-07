/**
 * AppError.js â€” Domain error with HTTP status code.
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
