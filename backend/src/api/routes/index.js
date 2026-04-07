/**
 * routes/index.js â€” Aggregates all route modules.
 */
const { Router }    = require("express");
const requestLogger = require("../middleware/requestLogger");
const healthRoutes  = require("./health.routes");
const problemRoutes = require("./problem.routes");

const router = Router();
router.use(requestLogger);
router.use(healthRoutes);
router.use(problemRoutes);

module.exports = router;
