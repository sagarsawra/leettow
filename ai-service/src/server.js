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
  logger.info(`${signal} received â€” shutting down`);
  server.close(() => { logger.info("Server closed"); process.exit(0); });
  setTimeout(() => process.exit(1), 10_000);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT",  () => shutdown("SIGINT"));

process.on("unhandledRejection", (reason) => {
  logger.error("Unhandled rejection", { reason: String(reason) });
  process.exit(1);
});
