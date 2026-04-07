const { Router }    = require("express");
const requestLogger = require("../middleware/requestLogger");
const hintRoutes    = require("./hint.routes");
const healthRoutes  = require("./health.routes");

const router = Router();
router.use(requestLogger);
router.use(hintRoutes);
router.use(healthRoutes);
module.exports = router;
