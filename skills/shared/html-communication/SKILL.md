---
name: html-communication
description: Use when the user asks to communicate through an HTML document, or mentions "HTML" with no other context. Covers plans, specs, write-ups, findings, summaries, reports, comparisons, and UI mockups shown as readable HTML.
---

# HTML Communication

## When to Use

Use this skill when the user wants a plan, spec, write-up, findings, summary, report, comparison, or set of UI mockups presented as readable HTML.

Do not use it for HTML that ships as part of a product.

## Document

Create one self-contained HTML file.

- Write it like a spec, not a landing page: dense, scannable, no hero section, no decorative chrome, no marketing voice, no em dashes.
- Default to a readable dark theme: a dark gray background (not pure black), light text with high contrast, and restrained accent colors. If the user names a color or style, follow it.
- Make it readable on a phone: use a responsive viewport and no fixed-width layout.
- Use semantic HTML, inline CSS, inline SVG, and HTTPS or data-URL images.
- Use an inline classic script only when interactivity materially helps. The page must still be useful without JavaScript.
- Give external links `target="_blank"` and `rel="noopener noreferrer"`.

Never include secrets, private URLs, or local filesystem paths in the document.

## UI Mocks

When the user asks for variants:

- Render real styled variants, not descriptions.
- Label them `A`, `B`, `C`, and so on, so the user can pick one by letter.
- Lay them out side by side for direct comparison.

## Output

1. Write the HTML file locally. Save it in the project's `.plans/` folder as `YYYY-MM-DD-short-slug.html`. Create `.plans/` if it does not exist.
2. To revise a document, update the same file. Create a new file only when the user asks for a new draft.
3. Report the absolute local path as a clickable link.

Do not open a browser unless the user asks.
