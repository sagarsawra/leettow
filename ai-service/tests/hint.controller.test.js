const request = require("supertest");
const app     = require("../src/app");

jest.mock("../src/services/hintService", () => ({
  generateHints: jest.fn().mockResolvedValue({
    hintLevels: [
      "Think about the core relationship between elements in this problem.",
      "Consider a structure that gives you fast lookups as you scan the input once.",
      "For each element, check whether the complement you need has already been seen. Store elements as you go.",
    ],
  }),
}));

describe("POST /generate-hint", () => {
  const ENDPOINT = "/generate-hint";

  it("returns 200 with hintLevels array for valid input", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "Two Sum", difficulty: "Easy" });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.hintLevels).toHaveLength(3);
  });

  it("returns 400 when title is missing", async () => {
    const res = await request(app).post(ENDPOINT).send({ difficulty: "Easy" });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/title/i);
  });

  it("returns 400 when title is too short", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "X" });
    expect(res.status).toBe(400);
  });

  it("accepts optional description field", async () => {
    const res = await request(app).post(ENDPOINT).send({
      title: "Longest Consecutive Sequence",
      difficulty: "Medium",
      description: "Given an unsorted array of integers...",
    });
    expect(res.status).toBe(200);
  });

  it("strips unknown fields silently", async () => {
    const res = await request(app).post(ENDPOINT).send({ title: "3Sum", unknownField: "ignored" });
    expect(res.status).toBe(200);
  });
});

describe("GET /health", () => {
  it("returns 200 with status ok", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("ok");
    expect(res.body.data.service).toBe("leettow-ai-service");
  });
});
