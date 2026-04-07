/**
 * server.js Entry point.
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
  logger.info(`${signal} received shutting down gracefully`);
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
