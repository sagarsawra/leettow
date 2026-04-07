/**
 * aiClient.js â€” Low-level HTTP adapter for the AI microservice.
 * The only file that knows the AI service wire protocol.
 */
const axios    = require("axios");
const config   = require("../../config");
const logger   = require("../../config/logger");
const AppError = require("../../utils/AppError");

const client = axios.create({
  baseURL: config.aiService.url,
  timeout: config.aiService.timeoutMs,
  headers: {
    "Content-Type": "application/json",
    ...(config.aiService.apiKey
      ? { Authorization: `Bearer ${config.aiService.apiKey}` }
      : {}),
  },
});

client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.code === "ECONNREFUSED" || error.code === "ENOTFOUND") {
      logger.error("AI service unreachable", { code: error.code, url: config.aiService.url });
      throw new AppError("AI service is currently unavailable.", 503);
    }
    if (error.code === "ECONNABORTED" || error.message?.includes("timeout")) {
      logger.warn("AI service timed out", { timeoutMs: config.aiService.timeoutMs });
      throw new AppError("AI service timed out. Please try again.", 504);
    }
    const status  = error.response?.status  ?? 500;
    const message = error.response?.data?.error ?? "AI service returned an error.";
    logger.error("AI service error response", { status, message });
    throw new AppError(message, status);
  }
);

async function requestHints(problemData) {
  const { data } = await client.post("/hints", { problem: problemData });
  return data.hints;
}

module.exports = { requestHints };
