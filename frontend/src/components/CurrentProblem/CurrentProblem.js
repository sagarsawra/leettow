import React from "react";
import "./CurrentProblem.css";

const DIFFICULTY_MAP = {
  Easy:    { label: "Easy",   cls: "difficulty--easy"   },
  Medium:  { label: "Medium", cls: "difficulty--medium" },
  Hard:    { label: "Hard",   cls: "difficulty--hard"   },
  Unknown: { label: "-",      cls: ""                   },
};

export default function CurrentProblem({ problem, status, error }) {
  const diff = DIFFICULTY_MAP[problem?.difficulty] ?? DIFFICULTY_MAP["Unknown"];

  return (
    <section className="section-card current-problem" aria-label="Current problem">
      <p className="section-title">Current Problem</p>

      {status === "loading" && (
        <div className="current-problem__skeleton" aria-busy="true" aria-label="Loading problem">
          <div className="skeleton skeleton--title" />
          <div className="skeleton skeleton--tags" />
        </div>
      )}

      {status === "no-problem" && (
        <div className="current-problem__empty">
          <p className="current-problem__empty-text">
            {error ?? "Open a problem on LeetCode to get started."}
          </p>
        </div>
      )}

      {status === "ready" && problem && (
        <div className="current-problem__content">
          <div className="current-problem__row">
            <h2 className="current-problem__title">{problem.title}</h2>
            <span className={`difficulty-badge ${diff.cls}`}>{diff.label}</span>
          </div>
          {problem.tags?.length > 0 && (
            <ul className="current-problem__tags" aria-label="Topic tags">
              {problem.tags.map((tag) => (
                <li key={tag} className="tag">{tag}</li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
