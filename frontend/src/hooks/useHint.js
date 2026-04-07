import { useState, useCallback, useRef } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const MAX_HINT_LEVEL = 3;

const DEV_HINTS = {
  1: "Think about the core data structure that naturally models this problem's constraints. What property must hold at every step?",
  2: "Consider how sorting or a specific traversal order might expose a pattern. Can you reduce this to a known subproblem?",
  3: "A HashSet gives you O(1) lookups. Start each streak only when the predecessor does not exist â€” this ensures O(n) overall.",
};

export default function useHint(problemTitle) {
  const [hint, setHint] = useState(null);
  const [hintLevel, setHintLevel] = useState(0);
  const [hintLoading, setHintLoading] = useState(false);
  const prevTitleRef = useRef(problemTitle);

  if (prevTitleRef.current !== problemTitle) {
    prevTitleRef.current = problemTitle;
  }

  const revealNextHint = useCallback(async () => {
    if (!problemTitle || hintLevel >= MAX_HINT_LEVEL) return;
    const nextLevel = hintLevel + 1;
    setHintLoading(true);
    try {
      let hintText;
      if (!isExtensionContext()) {
        await new Promise(r => setTimeout(r, 600));
        hintText = DEV_HINTS[nextLevel];
      } else {
        const response = await sendMessage("GET_HINT", { title: problemTitle, hintLevel: nextLevel });
        hintText = response.hint;
      }
      setHint(hintText);
      setHintLevel(nextLevel);
    } catch (err) {
      console.error("[LeetTow] Failed to fetch hint:", err);
    } finally {
      setHintLoading(false);
    }
  }, [problemTitle, hintLevel]);

  const resetHint = useCallback(() => {
    setHint(null);
    setHintLevel(0);
  }, []);

  return { hint, hintLevel, hintLoading, revealNextHint, resetHint, maxLevel: MAX_HINT_LEVEL };
}
