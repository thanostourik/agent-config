---
name: html-communication
description: Use when the user asks for HTML, including converting plans or other Markdown to HTML. Covers plans, specs, write-ups, findings, summaries, reports, comparisons, and UI mockups shown as readable HTML.
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
- Use semantic HTML, inline CSS in a `<style>` block, system fonts, inline SVG, and data-URL images. Do not load external CSS, CSS frameworks (such as Tailwind), web fonts, or remote images.
- Do not use JavaScript: no `<script>` tags, inline event handlers (such as `onclick`), or `javascript:` links. Use HTML and CSS for simple interactivity (such as `<details>`, `popover`, or `:checked`).
- Give external links `target="_blank"` and `rel="noopener noreferrer"`.

Never include secrets in the document.

## UI Mocks

When the user asks for variants:

- Render real styled variants, not descriptions.
- Label them `A`, `B`, `C`, and so on, so the user can pick one by letter.
- Lay them out side by side for direct comparison.

## Output

Plans come from Markdown first:

1. Write or update the Markdown plan in the project's `.plans/` folder, named `YYYY-MM-DD-short-slug.md`. If the plan already exists, use that file.
2. Create the HTML from that Markdown file. The HTML must show the same content as the Markdown.
3. Save the HTML next to the plan with the same name and an `.html` extension, for example `2026-10-08-auth-retry.html`.

Other documents go straight to HTML. Save them in the project's `.plans/` folder as `YYYY-MM-DD-short-slug.html`.

Create `.plans/` if it does not exist. The HTML files in `.plans/` are gitignored, so writing them needs no branch, even on main. To revise, update the same file. Create a new file only when the user asks for a new draft. For a plan, update the Markdown first, then regenerate the HTML.

Report the absolute local path to the HTML as a clickable link.

Do not open a browser unless the user asks.
