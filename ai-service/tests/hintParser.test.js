const { parseHintResponse } = require("../src/services/hintParser");

describe("hintParser", () => {
  it("accepts a valid 3-hint response", () => {
    const raw = JSON.stringify({ hintLevels: [
      "Think about what you are really being asked to find here, and whether you have seen something similar before.",
      "Consider a structure that allows you to check existence of a value in constant time as you move through the input.",
      "As you iterate, for each element, check whether the value that would complete your target already exists in the structure. If not, record the current element for future lookups.",
    ]});
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(true);
    expect(result.hints).toHaveLength(3);
  });

  it("rejects non-JSON input", () => {
    const result = parseHintResponse("not json at all");
    expect(result.valid).toBe(false);
    expect(result.reason).toMatch(/JSON/i);
  });

  it("rejects wrong number of hints", () => {
    const raw = JSON.stringify({ hintLevels: ["only one hint here that is long enough to pass the length check yes"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
    expect(result.reason).toMatch(/3/);
  });

  it("rejects missing hintLevels key", () => {
    const raw = JSON.stringify({ hints: ["a", "b", "c"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
  });

  it("rejects hints that are too short", () => {
    const raw = JSON.stringify({ hintLevels: ["short", "also short", "still short"] });
    const result = parseHintResponse(raw);
    expect(result.valid).toBe(false);
  });
});
