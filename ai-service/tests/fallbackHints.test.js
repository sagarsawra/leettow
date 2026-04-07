const { getFallbackHints } = require("../src/services/fallbackHints");

describe("fallbackHints", () => {
  it("returns exactly 3 hints for Easy",   () => expect(getFallbackHints("Easy")).toHaveLength(3));
  it("returns exactly 3 hints for Medium", () => expect(getFallbackHints("Medium")).toHaveLength(3));
  it("returns exactly 3 hints for Hard",   () => expect(getFallbackHints("Hard")).toHaveLength(3));

  it("returns default fallback for unknown difficulty", () => {
    expect(getFallbackHints("Unknown")).toHaveLength(3);
  });

  it("each hint is a non-empty string", () => {
    getFallbackHints("Hard").forEach((h) => {
      expect(typeof h).toBe("string");
      expect(h.length).toBeGreaterThan(0);
    });
  });
});
