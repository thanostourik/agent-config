---
name: render-plan
description: Render a plan from .plans/ to HTML, publish it to Postplan, and give the user the link. Use right after you create or change a plan file in .plans/, or when the user asks to render, publish, or open a plan in the browser.
---

# Render plan

After you create or change a plan in `.plans/`, run:

```bash
render-plan <absolute path to the plan .md>
```

The script writes `<plan>.html` next to the Markdown file, uploads it to
Postplan, and prints a `Plan published: https://...postplan.dev` line. Give
the user that URL. Run it again after every later edit of the same plan; the
upload updates the same draft, so the URL stays the same.
