// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

/**
 * ML Content Highlighter – Content Script
 *
 * Runs in the context of every web page. Extracts text nodes, sends them
 * to the background service worker for NLP analysis, and applies highlight
 * spans to the key passages returned by the analyser.
 */

(function () {
  "use strict";

  // ── Constants ────────────────────────────────────────────────────────────────
  const HIGHLIGHT_CLASS = "ml-highlight";
  const HIGHLIGHT_CATEGORY_ATTR = "data-ml-category";
  const MIN_TEXT_LENGTH = 40; // characters – skip very short nodes

  // ── State ────────────────────────────────────────────────────────────────────
  let config = {
    enabled: true,
    categories: ["key-point", "summary", "action-item"],
    highlightColor: {
      "key-point": "#FFEB3B",
      summary: "#A5D6A7",
      "action-item": "#90CAF9",
    },
  };

  // ── Initialisation ───────────────────────────────────────────────────────────
  loadConfig().then(() => {
    if (config.enabled) {
      analyseAndHighlight();
    }
  });

  // Listen for messages from the popup or background worker
  browser.runtime.onMessage.addListener((message) => {
    switch (message.action) {
      case "highlight":
        analyseAndHighlight();
        break;
      case "removeHighlights":
        removeAllHighlights();
        break;
      case "updateConfig":
        config = { ...config, ...message.config };
        removeAllHighlights();
        if (config.enabled) {
          analyseAndHighlight();
        }
        break;
      case "findText":
        findAndHighlightText(message.query);
        break;
    }
  });

  // ── Config helpers ───────────────────────────────────────────────────────────
  async function loadConfig() {
    try {
      const stored = await browser.storage.local.get("mlHighlighterConfig");
      if (stored.mlHighlighterConfig) {
        config = { ...config, ...stored.mlHighlighterConfig };
      }
    } catch (_) {
      // Storage not available; use defaults
    }
  }

  // ── DOM helpers ──────────────────────────────────────────────────────────────

  /**
   * Collect all visible text nodes whose content is long enough to analyse.
   */
  function collectTextNodes() {
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          const parent = node.parentElement;
          if (!parent) return NodeFilter.FILTER_REJECT;
          const tag = parent.tagName.toUpperCase();
          if (["SCRIPT", "STYLE", "NOSCRIPT", "TEXTAREA"].includes(tag)) {
            return NodeFilter.FILTER_REJECT;
          }
          const text = node.textContent.trim();
          if (text.length < MIN_TEXT_LENGTH) return NodeFilter.FILTER_SKIP;
          return NodeFilter.FILTER_ACCEPT;
        },
      }
    );

    const nodes = [];
    let node;
    while ((node = walker.nextNode())) {
      nodes.push(node);
    }
    return nodes;
  }

  /**
   * Wrap a text node's full content in a highlight span.
   */
  function highlightNode(textNode, category) {
    const color = config.highlightColor[category] || "#FFEB3B";
    const span = document.createElement("span");
    span.className = HIGHLIGHT_CLASS;
    span.setAttribute(HIGHLIGHT_CATEGORY_ATTR, category);
    span.style.backgroundColor = color;
    span.style.borderRadius = "2px";
    span.style.padding = "0 2px";
    span.textContent = textNode.textContent;
    textNode.parentNode.replaceChild(span, textNode);
  }

  /**
   * Remove all existing highlights, restoring plain text nodes.
   */
  function removeAllHighlights() {
    document.querySelectorAll(`.${HIGHLIGHT_CLASS}`).forEach((span) => {
      const text = document.createTextNode(span.textContent);
      span.parentNode.replaceChild(text, span);
    });
  }

  // ── NLP analysis ─────────────────────────────────────────────────────────────

  /**
   * Send page text to the background worker for NLP scoring and apply
   * highlights to the passages it identifies.
   */
  async function analyseAndHighlight() {
    const textNodes = collectTextNodes();
    if (textNodes.length === 0) return;

    const passages = textNodes.map((n, i) => ({
      id: i,
      text: n.textContent.trim(),
    }));

    try {
      const response = await browser.runtime.sendMessage({
        action: "analyseContent",
        passages,
        categories: config.categories,
      });

      if (!response || !response.highlights) return;

      response.highlights.forEach(({ id, category }) => {
        const node = textNodes[id];
        if (node && node.parentNode) {
          highlightNode(node, category);
        }
      });
    } catch (err) {
      console.warn("[ML Highlighter] Analysis failed:", err);
    }
  }

  /**
   * Highlight occurrences of a user-supplied query string (used by Siri).
   */
  function findAndHighlightText(query) {
    if (!query || query.trim() === "") return;
    removeAllHighlights();

    const lowerQuery = query.toLowerCase();
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      null
    );

    const nodesToHighlight = [];
    let node;
    while ((node = walker.nextNode())) {
      if (node.textContent.toLowerCase().includes(lowerQuery)) {
        nodesToHighlight.push(node);
      }
    }

    nodesToHighlight.forEach((n) => highlightNode(n, "key-point"));

    if (nodesToHighlight.length > 0) {
      // Scroll the first match into view
      const firstHighlight = document.querySelector(`.${HIGHLIGHT_CLASS}`);
      if (firstHighlight) {
        firstHighlight.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }

    return nodesToHighlight.length;
  }
})();
