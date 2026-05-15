/**
 * openaiClient.js — Low-level AI API adapter (now using Groq).
 *
 * This remains the ONLY file that calls the LLM.
 * Swapping providers later will still require changes only here.
 */
const Groq = require("groq-sdk");
const config = require("../config");
const logger = require("../config/logger");
const AppError = require("../utils/AppError");

// Singleton Groq client.
const groq = new Groq({ apiKey: config.groq.apiKey });

/**
 * Call the Groq chat completions API with a system + user prompt pair.
 * @param {string} systemPrompt
 * @param {string} userPrompt
 * @returns {Promise<string>} Raw response content from the model.
 */
async function callOpenAI(systemPrompt, userPrompt) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), config.groq.timeoutMs);

  try {
    logger.debug("Calling Groq", { model: config.groq.model });

    const response = await groq.chat.completions.create(
      {
        model: config.groq.model,
        temperature: config.groq.temperature,
        max_tokens: config.groq.maxTokens,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      },
      { signal: controller.signal }
    );

    const content = response.choices?.[0]?.message?.content;

    if (!content) {
      throw new AppError("Groq returned an empty response.", 502);
    }

    logger.debug("Groq response received", {
      model: response.model,
      finishReason: response.choices?.[0]?.finish_reason,
    });

    return content;

  } catch (err) {
    if (err.name === "AbortError" || err.code === "ERR_CANCELED") {
      logger.warn("Groq request timed out", { timeoutMs: config.groq.timeoutMs });
      throw new AppError("AI request timed out.", 504);
    }

    if (err?.status) {
      const msg = err.message || "Groq API error";
      logger.error("Groq API error", { status: err.status, message: msg });
      throw new AppError(msg, err.status >= 500 ? 502 : err.status);
    }

    if (err.name === "AppError") throw err;

    logger.error("Unexpected Groq client error", { message: err.message });
    throw new AppError("AI service error. Please try again.", 502);

  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = { callOpenAI };