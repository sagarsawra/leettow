/**
 * openaiClient.js â€” Low-level OpenAI API adapter.
 *
 * This is the ONLY file that imports and calls the OpenAI SDK.
 * Swapping to Anthropic, Gemini, or a self-hosted model requires
 * changing only this file â€” nothing else in the service changes.
 *
 * Design decisions:
 *   - Uses response_format: { type: "json_object" } to enforce JSON output
 *     at the API level, not just via prompting. Belt AND suspenders.
 *   - AbortController handles the timeout so the HTTP connection is actually
 *     severed â€” not just ignored â€” when the limit is hit.
 *   - The client is a singleton; re-instantiating on every request is wasteful.
 */
const OpenAI   = require("openai");
const config   = require("../config");
const logger   = require("../config/logger");
const AppError = require("../utils/AppError");

// Singleton OpenAI client.
const openai = new OpenAI({ apiKey: config.openai.apiKey });

/**
 * Call the OpenAI chat completions API with a system + user prompt pair.
 * @param {string} systemPrompt
 * @param {string} userPrompt
 * @returns {Promise<string>} Raw response content from the model.
 */
async function callOpenAI(systemPrompt, userPrompt) {
  const controller = new AbortController();
  const timeoutId  = setTimeout(() => controller.abort(), config.openai.timeoutMs);

  try {
    logger.debug("Calling OpenAI", { model: config.openai.model });

    const response = await openai.chat.completions.create(
      {
        model:           config.openai.model,
        temperature:     config.openai.temperature,
        max_tokens:      config.openai.maxTokens,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user",   content: userPrompt   },
        ],
      },
      { signal: controller.signal }
    );

    const content = response.choices?.[0]?.message?.content;

    if (!content) {
      throw new AppError("OpenAI returned an empty response.", 502);
    }

    logger.debug("OpenAI response received", {
      model:            response.model,
      promptTokens:     response.usage?.prompt_tokens,
      completionTokens: response.usage?.completion_tokens,
      finishReason:     response.choices?.[0]?.finish_reason,
    });

    return content;

  } catch (err) {
    if (err.name === "AbortError" || err.code === "ERR_CANCELED") {
      logger.warn("OpenAI request timed out", { timeoutMs: config.openai.timeoutMs });
      throw new AppError("AI request timed out.", 504);
    }

    if (err?.status) {
      const msg = err.message || "OpenAI API error";
      logger.error("OpenAI API error", { status: err.status, message: msg });
      throw new AppError(msg, err.status >= 500 ? 502 : err.status);
    }

    if (err.name === "AppError") throw err;

    logger.error("Unexpected OpenAI client error", { message: err.message });
    throw new AppError("AI service error. Please try again.", 502);

  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = { callOpenAI };
