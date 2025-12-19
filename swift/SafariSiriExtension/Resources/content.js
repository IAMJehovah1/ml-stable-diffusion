/**
 * SafariSiri Extension - Content Script
 * Handles content highlighting and communication with the Safari extension
 */

(function() {
    'use strict';
    
    // Configuration
    const HIGHLIGHT_CLASS = 'safarisiri-highlight';
    const HIGHLIGHT_COLOR = '#ffeb3b';
    const PRIORITY_HIGH_COLOR = '#ff9800';
    
    // State
    let highlightingEnabled = false;
    let currentHighlights = [];
    
    // Initialize extension
    function initialize() {
        injectStyles();
        setupMessageListener();
        
        // Request initial content analysis
        if (document.readyState === 'complete') {
            analyzePageContent();
        } else {
            window.addEventListener('load', analyzePageContent);
        }
    }
    
    // Inject highlighting styles
    function injectStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .${HIGHLIGHT_CLASS} {
                background-color: ${HIGHLIGHT_COLOR};
                transition: background-color 0.3s ease;
                padding: 2px 4px;
                border-radius: 3px;
            }
            
            .${HIGHLIGHT_CLASS}.priority-high {
                background-color: ${PRIORITY_HIGH_COLOR};
                font-weight: 500;
            }
            
            .${HIGHLIGHT_CLASS}:hover {
                opacity: 0.8;
                cursor: pointer;
            }
        `;
        document.head.appendChild(style);
    }
    
    // Setup message listener for extension communication
    function setupMessageListener() {
        safari.self.addEventListener('message', handleMessage);
    }
    
    // Handle messages from Safari extension
    function handleMessage(event) {
        switch (event.name) {
            case 'toggleHighlighting':
                toggleHighlighting(event.message.enabled);
                break;
            case 'highlightContent':
                applyHighlights(event.message.highlights, event.message.relevanceScore);
                break;
            case 'applySuggestions':
                displaySuggestions(event.message.suggestions);
                break;
        }
    }
    
    // Analyze page content and send to extension
    function analyzePageContent() {
        const content = extractPageContent();
        
        safari.extension.dispatchMessage('analyzeContent', {
            content: content,
            url: window.location.href,
            title: document.title
        });
    }
    
    // Extract meaningful text content from page
    function extractPageContent() {
        const textElements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article, section');
        let content = '';
        
        textElements.forEach(element => {
            content += element.textContent + ' ';
        });
        
        return content.trim().slice(0, 5000); // Limit content size
    }
    
    // Toggle highlighting on/off
    function toggleHighlighting(enabled) {
        highlightingEnabled = enabled;
        
        if (!enabled) {
            removeAllHighlights();
        } else {
            analyzePageContent();
        }
    }
    
    // Apply highlights to content based on ML analysis
    function applyHighlights(highlights, relevanceScore) {
        if (!highlightingEnabled || !highlights || highlights.length === 0) {
            return;
        }
        
        removeAllHighlights();
        
        highlights.forEach(highlight => {
            const keyword = highlight.keyword;
            const priority = highlight.priority || relevanceScore;
            
            highlightKeyword(keyword, priority);
        });
    }
    
    // Highlight specific keyword in content
    function highlightKeyword(keyword, priority) {
        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: function(node) {
                    // Skip script and style elements
                    const parent = node.parentElement;
                    if (parent && (parent.tagName === 'SCRIPT' || parent.tagName === 'STYLE')) {
                        return NodeFilter.FILTER_REJECT;
                    }
                    // Only nodes containing the keyword
                    if (node.textContent.toLowerCase().includes(keyword.toLowerCase())) {
                        return NodeFilter.FILTER_ACCEPT;
                    }
                    return NodeFilter.FILTER_SKIP;
                }
            }
        );
        
        const nodesToHighlight = [];
        let node;
        while (node = walker.nextNode()) {
            nodesToHighlight.push(node);
        }
        
        nodesToHighlight.forEach(textNode => {
            highlightTextNode(textNode, keyword, priority);
        });
    }
    
    // Highlight text within a text node
    function highlightTextNode(textNode, keyword, priority) {
        const text = textNode.textContent;
        const regex = new RegExp(`(${escapeRegex(keyword)})`, 'gi');
        
        if (!regex.test(text)) {
            return;
        }
        
        const parent = textNode.parentElement;
        if (parent.classList.contains(HIGHLIGHT_CLASS)) {
            return; // Already highlighted
        }
        
        const fragment = document.createDocumentFragment();
        const parts = text.split(regex);
        
        parts.forEach(part => {
            if (part.toLowerCase() === keyword.toLowerCase()) {
                const span = document.createElement('span');
                span.className = HIGHLIGHT_CLASS;
                if (priority > 0.7) {
                    span.classList.add('priority-high');
                }
                span.textContent = part;
                span.setAttribute('data-safarisiri', 'true');
                fragment.appendChild(span);
                currentHighlights.push(span);
            } else if (part) {
                fragment.appendChild(document.createTextNode(part));
            }
        });
        
        textNode.parentNode.replaceChild(fragment, textNode);
    }
    
    // Remove all highlights
    function removeAllHighlights() {
        currentHighlights.forEach(element => {
            const parent = element.parentNode;
            if (parent) {
                parent.replaceChild(document.createTextNode(element.textContent), element);
                parent.normalize(); // Merge adjacent text nodes
            }
        });
        currentHighlights = [];
    }
    
    // Display content suggestions
    function displaySuggestions(suggestions) {
        if (!suggestions || suggestions.length === 0) {
            return;
        }
        
        // Create suggestion panel
        const panel = createSuggestionPanel(suggestions);
        document.body.appendChild(panel);
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            panel.style.opacity = '0';
            setTimeout(() => panel.remove(), 300);
        }, 5000);
    }
    
    // Create suggestion panel element
    function createSuggestionPanel(suggestions) {
        const panel = document.createElement('div');
        panel.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: white;
            border: 2px solid #2196F3;
            border-radius: 8px;
            padding: 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            z-index: 10000;
            max-width: 300px;
            transition: opacity 0.3s ease;
        `;
        
        const title = document.createElement('div');
        title.textContent = 'ML Suggestions';
        title.style.cssText = 'font-weight: bold; margin-bottom: 10px; color: #2196F3;';
        panel.appendChild(title);
        
        suggestions.forEach(suggestion => {
            const item = document.createElement('div');
            item.textContent = `• ${suggestion.suggestion}`;
            item.style.cssText = 'margin: 5px 0; color: #333;';
            panel.appendChild(item);
        });
        
        return panel;
    }
    
    // Escape special regex characters
    function escapeRegex(string) {
        return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
    
    // Start the extension
    initialize();
})();
