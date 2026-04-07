const request = require("supertest");
const app     = require("../src/app");

jest.mock("../src/services/ai/aiService", () => ({
  getHints: jest.fn().mockResolvedValue([
    "Hint level 1 â€” vague",
    "Hint level 2 â€” directional",
    "Hint level 3 â€” algorithmic",
  ]),
}));

describe("POST /api/problem/analyze", () => {
  const ENDPOINT = "/api/problem/analyze";

  it("returns 200 with a well-formed payload", async () => {
    const res = await request(app).post(ENDPOINT).send({
      title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"],
    });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.problemTitle).toBe("Two Sum");
    expect(res.body.data.hintLevels).toHaveLength(3);
    expect(res.body.data.similarProblems.length).toBeGreaterThan(0);
  });

  it("returns 400 when title is missing", async () => {
    const res = await request(app).post(ENDPOINT).send({ difficulty: "Easy" });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/title/i);
  });

  it("returns 400 when title is too short", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "A" });
    expect(res.status).toBe(400);
  });

  it("accepts optional fields gracefully", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "Valid Parentheses" });
    expect(res.status).toBe(200);
    expect(res.body.data.hintLevels).toHaveLength(3);
  });

  it("strips unknown fields silently", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "3Sum", unknownField: "ignored" });
    expect(res.status).toBe(200);
  });
});

describe("GET /api/health", () => {
  it("returns 200 with status ok", async () => {
    const res = await request(app).get("/api/health");
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("ok");
  });
});
