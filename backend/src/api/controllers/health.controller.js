/**
 * health.controller.js â€” GET /api/health
 */
const { ok }   = require("../../utils/respond");
const config   = require("../../config");

function getHealth(req, res) {
  return ok(res, {
    status:    "ok",
    env:       config.env,
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
}

module.exports = { getHealth };
