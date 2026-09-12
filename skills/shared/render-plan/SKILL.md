---
name: render-plan
metadata:
  harness: "grok, opencode"
description: Render a plan from .plans/ to HTML, publish it to Postplan, and give the user the link. Use after you create or change a plan in .plans/, or when the user asks to publish or open a plan in the browser.
---

# Render plan

Run:

```bash
render-plan <path to the plan .md>
```

Give the user the `https://...postplan.dev` link it prints. Run it again after
every later change to the plan. The link stays the same.
