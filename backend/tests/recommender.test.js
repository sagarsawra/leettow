const { getSimilarProblems, scoreCandidate } = require("../src/services/recommender");

describe("Recommender â€” getSimilarProblems", () => {
  it("returns up to 5 results by default", () => {
    const results = getSimilarProblems({ title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"] });
    expect(results.length).toBeLessThanOrEqual(5);
    expect(results.length).toBeGreaterThan(0);
  });

  it("excludes the exact queried problem by title", () => {
    const results = getSimilarProblems({ title: "Two Sum", difficulty: "Easy", tags: ["Array"] });
    expect(results.find((r) => r.title === "Two Sum")).toBeUndefined();
  });

  it("each result has title, difficulty, and link", () => {
    const results = getSimilarProblems({ title: "Coin Change", difficulty: "Medium", tags: ["Dynamic Programming"] });
    results.forEach((r) => {
      expect(r).toHaveProperty("title");
      expect(r).toHaveProperty("difficulty");
      expect(r).toHaveProperty("link");
    });
  });

  it("returns results even with no tags provided", () => {
    const results = getSimilarProblems({ title: "Number of Islands", difficulty: "Medium", tags: [] });
    expect(results.length).toBeGreaterThan(0);
  });

  it("respects custom limit", () => {
    const results = getSimilarProblems({ title: "3Sum", difficulty: "Medium", tags: ["Array"] }, 3);
    expect(results.length).toBeLessThanOrEqual(3);
  });
});

describe("Recommender â€” scoreCandidate", () => {
  it("scores high tag overlap above low tag overlap", () => {
    const query     = { title: "Two Sum", difficulty: "Easy", tags: ["Array","Hash Table"] };
    const highMatch = { title: "Contains Duplicate", difficulty: "Easy",   tags: ["Array","Hash Table"], keywords: ["duplicate","hash"], link: "" };
    const lowMatch  = { title: "Trapping Rain Water", difficulty: "Hard",  tags: ["Stack","Monotonic Stack"], keywords: ["rain","trap"],  link: "" };
    expect(scoreCandidate(query, highMatch)).toBeGreaterThan(scoreCandidate(query, lowMatch));
  });
});
