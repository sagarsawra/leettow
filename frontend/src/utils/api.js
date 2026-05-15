/**
 * api.js — HTTP client for the LeetTow backend API.
 */

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:3001";
const REQUEST_TIMEOUT_MS = 12000;

/**
 * Analyze a problem via the backend.
 * @param {{ title: string, description?: string, difficulty?: string, tags?: string[] }} problem
 * @returns {Promise<{ problemTitle: string, hintLevels: string[], similarProblems: Array }>}
 */
export async function analyzeProblem(problem) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(`${BACKEND_URL}/api/problem/analyze`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        title:       problem.title,
        description: problem.description || "",
        difficulty:  problem.difficulty || "Unknown",
        tags:        problem.tags || [],
      }),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => null);
      throw new Error(body?.error || `Backend returned ${response.status}`);
    }

    const body = await response.json();
    if (!body.success) {
      throw new Error(body.error || "Backend returned an error.");
    }

    return body.data;
  } catch (err) {
    if (err.name === "AbortError") {
      throw new Error("Request timed out. Please try again.");
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}
