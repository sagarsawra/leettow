const { ok } = require("../../utils/respond");
const config = require("../../config");

function getHealth(req, res) {
  return ok(res, {
    status:    "ok",
    service:   "leettow-ai-service",
    model:     config.openai.model,
    env:       config.env,
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
}

module.exports = { getHealth };
