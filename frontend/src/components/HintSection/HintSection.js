import React from "react";
import "./HintSection.css";

const MAX_LEVEL = 3;
const LEVEL_LABELS = { 0: null, 1: "Vague Nudge", 2: "Directional", 3: "Algorithmic" };

export default function HintSection({ hint, hintLevel, loading, onReveal, onReset, disabled }) {
  const atMax = hintLevel >= MAX_LEVEL;
  const hasHint = hintLevel > 0 && hint;

  return (
    <section className="section-card hint-section" aria-label="AI hint">
      <div className="hint-section__header">
        <p className="section-title">AI Hint</p>
        {hintLevel > 0 && (
          <span className="hint-level-badge">Level {hintLevel} â€” {LEVEL_LABELS[hintLevel]}</span>
        )}
      </div>

      {hasHint && (
        <div className="hint-section__content" role="status" aria-live="polite">
          <p className="hint-text">{hint}</p>
          <div className="hint-dots" aria-label={`Hint level ${hintLevel} of ${MAX_LEVEL}`}>
            {Array.from({ length: MAX_LEVEL }, (_, i) => (
              <span key={i} className={`hint-dot ${i < hintLevel ? "hint-dot--active" : ""}`} />
            ))}
          </div>
        </div>
      )}

      {!hasHint && !loading && (
        <p className="hint-section__placeholder">
          {disabled ? "Hints unlock once a problem is detected." : "Hints are revealed progressively â€” no spoilers."}
        </p>
      )}

      {loading && (
        <div className="hint-section__loading" aria-busy="true">
          <span className="spinner" aria-hidden="true" />
          <span className="hint-section__loading-text">Thinking...</span>
        </div>
      )}

      <div className="hint-section__actions">
        <button
          className="btn btn--primary"
          onClick={onReveal}
          disabled={disabled || loading || atMax}
          aria-label={hintLevel === 0 ? "Show first hint" : "Show next hint level"}
        >
          {atMax ? "Max hints reached" : hintLevel === 0 ? "Show Hint" : "Next Hint"}
        </button>
        {hintLevel > 0 && (
          <button className="btn btn--ghost" onClick={onReset} disabled={loading} aria-label="Reset hints">
            Reset
          </button>
        )}
      </div>
    </section>
  );
}
