import React from "react";
import "./SimilarProblems.css";

const DIFFICULTY_CLS = {
  Easy:   "problem-item__difficulty--easy",
  Medium: "problem-item__difficulty--medium",
  Hard:   "problem-item__difficulty--hard",
};

export default function SimilarProblems({ problems, loading, hasProblem }) {
  return (
    <section className="section-card similar-problems" aria-label="Similar problems">
      <p className="section-title">Similar Problems</p>

      {!hasProblem && !loading && (
        <p className="similar-problems__placeholder">
          Detected problem will surface related questions here.
        </p>
      )}

      {loading && (
        <ul className="similar-problems__list" aria-busy="true">
          {Array.from({ length: 4 }, (_, i) => (
            <li key={i} className="problem-item problem-item--skeleton">
              <div className="skeleton skeleton--problem-title" />
              <div className="skeleton skeleton--problem-diff" />
            </li>
          ))}
        </ul>
      )}

      {!loading && problems.length > 0 && (
        <ul className="similar-problems__list">
          {problems.map((p) => (
            <li key={p.id}>
              <a
                className="problem-item"
                href={p.url || p.link}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${p.title} - ${p.difficulty}`}
              >
                {p.number != null && <span className="problem-item__number">#{p.number}</span>}
                <span className="problem-item__title">{p.title}</span>
                <span className={`problem-item__difficulty ${DIFFICULTY_CLS[p.difficulty] ?? ""}`}>
                  {p.difficulty}
                </span>
                <span className="problem-item__arrow" aria-hidden="true">&#8599;</span>
              </a>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
