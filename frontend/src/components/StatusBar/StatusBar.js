import React from "react";
import "./StatusBar.css";

const STATUS_CONFIG = {
  loading:      { label: "Detecting problem...", cls: "status--loading",    dot: true  },
  ready:        { label: "Ready",                cls: "status--ready",      dot: true  },
  "no-problem": { label: "No problem detected",  cls: "status--idle",       dot: false },
  error:        { label: "Error",                cls: "status--error",      dot: true  },
};

export default function StatusBar({ status, error }) {
  const config = STATUS_CONFIG[status] ?? STATUS_CONFIG["no-problem"];
  const label = status === "error" && error ? `Error: ${error}` : config.label;

  return (
    <footer className={`status-bar ${config.cls}`} role="status" aria-live="polite">
      {config.dot && <span className="status-bar__dot" aria-hidden="true" />}
      <span className="status-bar__label">{label}</span>
      <span className="status-bar__brand">leettow v1.0</span>
    </footer>
  );
}
