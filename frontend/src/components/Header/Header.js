import React from "react";
import "./Header.css";

export default function Header() {
  return (
    <header className="header">
      <div className="header__logo" aria-hidden="true">
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none" aria-hidden="true">
          <rect width="22" height="22" rx="5" fill="#00b4d8" />
          <path d="M5 6h4v7h4v3H5V6z" fill="#0d1117" />
          <path d="M14 6h3v4h-1.5v6H14V6z" fill="#0d1117" />
        </svg>
      </div>
      <div className="header__text">
        <h1 className="header__title">LeetTow</h1>
        <span className="header__subtitle">AI Assistant</span>
      </div>
      <div className="header__badge">AI</div>
    </header>
  );
}
