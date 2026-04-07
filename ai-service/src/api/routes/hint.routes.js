const { Router }       = require("express");
const { generateHint } = require("../controllers/hint.controller");

const router = Router();

/**
 * POST /generate-hint
 * Body: { title, description?, difficulty? }
 * Response: { success, data: { hintLevels: string[] } }
 */
router.post("/generate-hint", generateHint);

module.exports = router;
