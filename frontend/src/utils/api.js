/**
 * api.js — HTTP client for the LeetTow backend API.
 */

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:3001";

/**
 * Analyze a problem via the backend.
 * @param {{ title: string, difficulty?: string, tags?: string[] }} problem
 * @returns {Promise<{ problemTitle: string, hintLevels: string[], similarProblems: Array }>}
 */
export async function analyzeProblem(problem) {
  const response = await fetch(`${BACKEND_URL}/api/problem/analyze`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title:      problem.title,
      difficulty: problem.difficulty || "Unknown",
      tags:       problem.tags || [],
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
}
