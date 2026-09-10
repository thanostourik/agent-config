---
name: render-plan
description: Render a plan from .plans/ to a styled HTML file next to it and give the user the link. Use right after you create or change a plan file in .plans/, or when the user asks to render, publish, or open a plan in the browser.
---

# Render plan

After you create or change a plan in `.plans/`, run:

```bash
render-plan <absolute path to the plan .md>
```

The script writes `<plan>.html` next to the Markdown file and prints a
`file://` link. Give the user that link. Run it again after every later edit
of the same plan, so the HTML stays current.
