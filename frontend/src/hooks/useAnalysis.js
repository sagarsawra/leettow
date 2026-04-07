import { useState, useEffect, useCallback, useRef } from "react";
import { analyzeProblem } from "../utils/api";

const MAX_HINT_LEVEL = 3;

const DEV_HINTS = [
  "Think about the core data structure that naturally models this problem's constraints. What property must hold at every step?",
  "Consider how sorting or a specific traversal order might expose a pattern. Can you reduce this to a known subproblem?",
  "Think about the trade-off between time and space. Accepting extra memory often unlocks a significantly faster traversal strategy.",
];

export default function useAnalysis(problem) {
  const [hintLevels, setHintLevels] = useState([]);
  const [similarProblems, setSimilarProblems] = useState([]);
  const [currentLevel, setCurrentLevel] = useState(0);
  const [hint, setHint] = useState(null);
  const [analysisLoading, setAnalysisLoading] = useState(false);
  const [hintLoading, setHintLoading] = useState(false);
  const [analysisError, setAnalysisError] = useState(null);
  const analyzedTitleRef = useRef(null);

  // Fetch analysis from backend when problem changes
  useEffect(() => {
    if (!problem?.title) return;
    if (analyzedTitleRef.current === problem.title) return;

    let cancelled = false;
    setAnalysisLoading(true);
    setAnalysisError(null);
    setHintLevels([]);
    setSimilarProblems([]);
    setCurrentLevel(0);
    setHint(null);

    async function fetchAnalysis() {
      try {
        const data = await analyzeProblem(problem);
        if (!cancelled) {
          analyzedTitleRef.current = problem.title;
          setHintLevels(data.hintLevels || []);
          setSimilarProblems(
            (data.similarProblems || []).map((p, i) => ({
              id: i,
              number: i + 1,
              title: p.title,
              difficulty: p.difficulty,
              url: p.link,
            }))
          );
        }
      } catch (err) {
        if (!cancelled) {
          setAnalysisError(err.message);
          // Use dev fallback hints
          setHintLevels(DEV_HINTS);
          setSimilarProblems([]);
        }
      } finally {
        if (!cancelled) setAnalysisLoading(false);
      }
    }

    fetchAnalysis();
    return () => { cancelled = true; };
  }, [problem]);

  const revealNextHint = useCallback(() => {
    if (currentLevel >= MAX_HINT_LEVEL || currentLevel >= hintLevels.length) return;
    setHintLoading(true);
    // Simulate brief delay for UX
    setTimeout(() => {
      const nextLevel = currentLevel + 1;
      setHint(hintLevels[nextLevel - 1]);
      setCurrentLevel(nextLevel);
      setHintLoading(false);
    }, 300);
  }, [currentLevel, hintLevels]);

  const resetHint = useCallback(() => {
    setHint(null);
    setCurrentLevel(0);
  }, []);

  return {
    hint,
    hintLevel: currentLevel,
    hintLoading: hintLoading || analysisLoading,
    revealNextHint,
    resetHint,
    maxLevel: MAX_HINT_LEVEL,
    similarProblems,
    similarLoading: analysisLoading,
    analysisError,
  };
}
