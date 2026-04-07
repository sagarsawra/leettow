import { useState, useEffect } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const DEV_MOCK_SIMILAR = [
  { id: 1,   number: 1,   title: "Two Sum",                                        difficulty: "Easy",   url: "https://leetcode.com/problems/two-sum/" },
  { id: 3,   number: 3,   title: "Longest Substring Without Repeating Characters", difficulty: "Medium", url: "https://leetcode.com/problems/longest-substring-without-repeating-characters/" },
  { id: 15,  number: 15,  title: "3Sum",                                           difficulty: "Medium", url: "https://leetcode.com/problems/3sum/" },
  { id: 76,  number: 76,  title: "Minimum Window Substring",                       difficulty: "Hard",   url: "https://leetcode.com/problems/minimum-window-substring/" },
  { id: 167, number: 167, title: "Two Sum II - Input Array Is Sorted",             difficulty: "Medium", url: "https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/" },
];

export default function useSimilarProblems(problemTitle) {
  const [problems, setProblems] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!problemTitle) return;
    let cancelled = false;
    setLoading(true);

    async function fetch() {
      try {
        let result;
        if (!isExtensionContext()) {
          await new Promise(r => setTimeout(r, 600));
          result = DEV_MOCK_SIMILAR;
        } else {
          const response = await sendMessage("GET_SIMILAR_PROBLEMS", { title: problemTitle });
          result = response.problems;
        }
        if (!cancelled) setProblems(result);
      } catch (err) {
        console.error("[LeetTow] Failed to fetch similar problems:", err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetch();
    return () => { cancelled = true; };
  }, [problemTitle]);

  return { problems, loading };
}
