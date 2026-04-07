import React from "react";
import Header from "./components/Header/Header";
import CurrentProblem from "./components/CurrentProblem/CurrentProblem";
import HintSection from "./components/HintSection/HintSection";
import SimilarProblems from "./components/SimilarProblems/SimilarProblems";
import StatusBar from "./components/StatusBar/StatusBar";
import useProblemData from "./hooks/useProblemData";
import useHint from "./hooks/useHint";
import useSimilarProblems from "./hooks/useSimilarProblems";
import "./styles/app.css";

export default function App() {
  const { problem, status, error } = useProblemData();
  const { hint, hintLevel, hintLoading, revealNextHint, resetHint } = useHint(problem?.title);
  const { problems: similarProblems, loading: similarLoading } = useSimilarProblems(problem?.title);

  return (
    <div className="app">
      <Header />
      <main className="app__main">
        <CurrentProblem problem={problem} status={status} error={error} />
        <HintSection
          hint={hint}
          hintLevel={hintLevel}
          loading={hintLoading}
          onReveal={revealNextHint}
          onReset={resetHint}
          disabled={!problem}
        />
        <SimilarProblems
          problems={similarProblems}
          loading={similarLoading}
          hasProblem={!!problem}
        />
      </main>
      <StatusBar status={status} error={error} />
    </div>
  );
}
