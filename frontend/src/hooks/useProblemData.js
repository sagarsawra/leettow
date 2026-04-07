import { useState, useEffect } from "react";
import { sendMessage, isExtensionContext } from "../utils/messaging";

const DEV_MOCK_PROBLEM = {
  title: "Longest Consecutive Sequence",
  difficulty: "Medium",
  tags: ["Array", "Hash Table", "Union Find"],
  detectedAt: Date.now(),
};

export default function useProblemData() {
  const [problem, setProblem] = useState(null);
  const [status, setStatus] = useState("loading");
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchProblem() {
      setStatus("loading");
      setError(null);

      if (!isExtensionContext()) {
        // Dev mode: use mock data after a short delay
        setTimeout(() => {
          if (!cancelled) {
            setProblem(DEV_MOCK_PROBLEM);
            setStatus("ready");
          }
        }, 800);
        return;
      }

      try {
        const response = await sendMessage("GET_PROBLEM_DATA");
        if (!cancelled) {
          if (response.data) {
            setProblem(response.data);
            setStatus("ready");
          } else {
            setStatus("no-problem");
          }
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message);
          setStatus("no-problem");
        }
      }
    }

    fetchProblem();
    return () => { cancelled = true; };
  }, []);

  return { problem, status, error };
}
