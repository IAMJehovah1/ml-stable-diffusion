// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

/**
 * ML Content Highlighter – Background Service Worker
 *
 * Receives text passages from the content script, performs lightweight
 * NLP scoring (keyword density, sentence position, TF-IDF-like heuristics),
 * and returns a list of passage IDs with their assigned categories.
 *
 * On Apple platforms the native Swift layer can be reached via
 * browser.runtime.sendNativeMessage for heavier on-device ML inference.
 */

"use strict";

// ── NLP helpers ──────────────────────────────────────────────────────────────

const STOPWORDS = new Set([
  "a","an","the","and","or","but","is","are","was","were","be","been","being",
  "have","has","had","do","does","did","will","would","could","should","may",
  "might","shall","can","to","of","in","on","at","by","for","with","about",
  "as","into","through","from","up","down","out","over","that","this","these",
  "those","it","its","i","we","you","he","she","they","them","their","our",
  "your","my","his","her","so","if","not","no","nor","yet","both","either",
  "each","all","any","more","most","other","some","such","than","then","there",
  "when","where","which","while","who","whom","how",
]);

/**
 * Compute term-frequency map for a piece of text.
 */
function termFrequency(text) {
  const tf = new Map();
  const words = text.toLowerCase().match(/\b[a-z]{3,}\b/g) || [];
  for (const word of words) {
    if (!STOPWORDS.has(word)) {
      tf.set(word, (tf.get(word) || 0) + 1);
    }
  }
  return tf;
}

/**
 * Score a single passage relative to the document-level term frequency map.
 * Returns a value in [0, 1].
 */
function scorePassage(passageTF, docTF, totalWords) {
  if (totalWords === 0) return 0;
  let score = 0;
  for (const [term, count] of passageTF) {
    const docFreq = docTF.get(term) || 0;
    // Reward terms that are prominent in the document but not ubiquitous
    score += (count / totalWords) * Math.log(1 + docFreq);
  }
  return Math.min(score, 1);
}

/**
 * Assign a category to a passage based on heuristic signals.
 */
function categorisePassage(text, score, index, total) {
  const lower = text.toLowerCase();

  // Action items: sentences beginning with an imperative-like verb
  const actionVerbs = /^(please |to )?(click|open|navigate|go to|download|install|enable|disable|configure|set|add|remove|select|choose|update|check|ensure|make sure)/;
  if (actionVerbs.test(lower.trim())) return "action-item";

  // Summaries: typically appear near the start or end of a document
  const relativePos = total > 0 ? index / total : 0;
  if ((relativePos < 0.1 || relativePos > 0.88) && score > 0.3) return "summary";

  // Key points: high-scoring passages in the body
  if (score > 0.45) return "key-point";

  return null; // Not significant enough to highlight
}

// ── Message handling ─────────────────────────────────────────────────────────

browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.action === "analyseContent") {
    const result = analyseContent(message.passages, message.categories || []);
    sendResponse(result);
    return true; // Keep channel open for async response
  }
  return false;
});

/**
 * Core analysis function.
 * @param {Array<{id:number, text:string}>} passages
 * @param {string[]} enabledCategories
 * @returns {{ highlights: Array<{id:number, category:string}> }}
 */
function analyseContent(passages, enabledCategories) {
  if (!passages || passages.length === 0) {
    return { highlights: [] };
  }

  // Build document-level TF map
  const docTF = new Map();
  let totalWords = 0;
  const passageTFs = passages.map(({ text }) => {
    const tf = termFrequency(text);
    for (const [term, count] of tf) {
      docTF.set(term, (docTF.get(term) || 0) + count);
      totalWords += count;
    }
    return tf;
  });

  const total = passages.length;
  const highlights = [];

  passages.forEach(({ id, text }, index) => {
    const tf = passageTFs[index];
    const score = scorePassage(tf, docTF, totalWords);
    const category = categorisePassage(text, score, index, total);

    if (category && (enabledCategories.length === 0 || enabledCategories.includes(category))) {
      highlights.push({ id, category });
    }
  });

  return { highlights };
}
