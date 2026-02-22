// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

/**
 * ML Content Highlighter – Popup Script
 *
 * Manages the popup UI: loads persisted configuration, syncs toggle state,
 * and sends messages to the active tab's content script.
 */

"use strict";

// ── Default configuration ────────────────────────────────────────────────────
const DEFAULT_CONFIG = {
  enabled: true,
  categories: ["key-point", "summary", "action-item"],
  highlightColor: {
    "key-point": "#FFEB3B",
    summary: "#A5D6A7",
    "action-item": "#90CAF9",
  },
};

// ── DOM references ───────────────────────────────────────────────────────────
const enabledToggle = document.getElementById("enabledToggle");
const catCheckboxes = document.querySelectorAll("[data-category]");
const highlightBtn = document.getElementById("highlightBtn");
const clearBtn = document.getElementById("clearBtn");
const searchInput = document.getElementById("searchInput");
const searchBtn = document.getElementById("searchBtn");
const searchStatus = document.getElementById("searchStatus");

// Colour swatches
const swatches = {
  "key-point": document.getElementById("swatchKeyPoint"),
  summary: document.getElementById("swatchSummary"),
  "action-item": document.getElementById("swatchAction"),
};

// ── Initialisation ───────────────────────────────────────────────────────────
let config = { ...DEFAULT_CONFIG };

(async function init() {
  await loadConfig();
  renderUI();
  bindEvents();
})();

// ── Persistence ──────────────────────────────────────────────────────────────
async function loadConfig() {
  try {
    const stored = await browser.storage.local.get("mlHighlighterConfig");
    if (stored.mlHighlighterConfig) {
      config = { ...DEFAULT_CONFIG, ...stored.mlHighlighterConfig };
    }
  } catch (_) {
    // Use defaults if storage is unavailable
  }
}

async function saveConfig() {
  try {
    await browser.storage.local.set({ mlHighlighterConfig: config });
  } catch (_) {}
}

// ── UI helpers ───────────────────────────────────────────────────────────────
function renderUI() {
  enabledToggle.checked = config.enabled;

  catCheckboxes.forEach((cb) => {
    const category = cb.dataset.category;
    cb.checked = config.categories.includes(category);

    const swatch = swatches[category];
    if (swatch) {
      swatch.style.backgroundColor = config.highlightColor[category] || "#ccc";
    }
  });
}

function getActiveTab() {
  return browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => tabs[0]);
}

async function sendToContent(message) {
  const tab = await getActiveTab();
  if (tab) {
    return browser.tabs.sendMessage(tab.id, message);
  }
}

// ── Event bindings ───────────────────────────────────────────────────────────
function bindEvents() {
  // Master enable/disable toggle
  enabledToggle.addEventListener("change", async () => {
    config.enabled = enabledToggle.checked;
    await saveConfig();
    await sendToContent({ action: "updateConfig", config });
  });

  // Category toggles
  catCheckboxes.forEach((cb) => {
    cb.addEventListener("change", async () => {
      const category = cb.dataset.category;
      if (cb.checked) {
        if (!config.categories.includes(category)) {
          config.categories.push(category);
        }
      } else {
        config.categories = config.categories.filter((c) => c !== category);
      }
      await saveConfig();
      await sendToContent({ action: "updateConfig", config });
    });
  });

  // Highlight Now button
  highlightBtn.addEventListener("click", async () => {
    await sendToContent({ action: "highlight" });
  });

  // Clear Highlights button
  clearBtn.addEventListener("click", async () => {
    await sendToContent({ action: "removeHighlights" });
  });

  // Search / Siri find-on-page
  async function runSearch() {
    const query = searchInput.value.trim();
    if (!query) {
      searchStatus.textContent = "Please enter a search term.";
      return;
    }
    try {
      const count = await sendToContent({ action: "findText", query });
      if (typeof count === "number") {
        searchStatus.textContent =
          count === 0
            ? "No matches found."
            : `Found ${count} match${count !== 1 ? "es" : ""}.`;
      } else {
        searchStatus.textContent = "Search complete.";
      }
    } catch (_) {
      searchStatus.textContent = "Could not reach the page.";
    }
  }

  searchBtn.addEventListener("click", runSearch);
  searchInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") runSearch();
  });
}
