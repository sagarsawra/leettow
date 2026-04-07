/**
 * requestLogger.js â€” Attaches a unique request ID for log tracing.
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
