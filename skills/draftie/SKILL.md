---
name: draftie
description: Publish one HTML file with draftie and return its link, or read a page from a draftie link. Use when the user asks to publish, share or upload a plan, report, analysis, write-up or mockup as HTML, or gives a link whose path starts with /api/d/.
---

# draftie

draftie hosts single HTML files. `draftie upload` returns a stable link. Uploading the same file
again adds a version at the same link.

## Read a page from a link

Run the CLI. Do not use a browser or web search: a page that is not public needs the API key,
which only the CLI sends.

```sh
npx draftie get '<link>' > /tmp/draftie-page.html
```

- The link may end in `/raw` or not. `<link>/v/3` is version 3.
- If the command fails, report its message. Do not replace the page with a guess.

## Write the HTML

Write one complete, static HTML file that needs nothing but itself. No JavaScript runs in a
draftie page, and `draftie upload` refuses a file that holds any.

Works:

- Inline CSS in a `<style>` block or in `style` attributes.
- Images, video and audio from `https:` addresses or `data:` URLs.
- Links to other pages. A link with `target="_blank"` opens a new tab.
- `<details>` and CSS such as `:target` and `:checked`, for parts that open, close or switch.
- A `<title>`. It becomes the page's name.

Does not work:

- JavaScript: `<script>`, inline handlers such as `onclick`, and `javascript:` links.
- `<link rel="stylesheet">`, web fonts from an address, and CSS `@import`. Put the CSS inline.
- Forms, `<iframe>`, `<object>`, `<embed>`, and `<meta http-equiv="refresh">`.

Never put secrets, tokens or passwords in the file. The file must be UTF-8 and at most 2 MB.

## Upload

```sh
npx draftie upload <file>
```

It prints `URL:`, the link for people, and `Raw HTML:`, the link for agents. Give the user the
`URL:` line.

- `--visibility private|public` sets who sees the page. `private`, the default, is only the
  user, signed in. `public` is anyone with the link, without signing in. Use `public` only when
  the user wants someone else to open the link.
- `--expires 7d` deletes the page after that time: `30m`, `12h`, `7d`, `2w`, or `never`.
- `--description "<text>"` sets a short description for the page list.
- The CLI remembers which file went to which page. `--new` uploads the file as a new page.
  `--page <id>` adds a version to another page.
- "Unchanged" means the file's bytes equal the latest version, so no version was added.

If the upload fails with "an upload needs an API key", tell the user to run
`npx draftie auth login`. Only they can sign in.

If it fails with "this HTML holds …", remove what the message names and upload again.

## Change or delete a page

`<page>` is the file that was uploaded, the page's link, or its id.

```sh
npx draftie set <page> --visibility public
npx draftie set <page> --expires never
npx draftie delete <page> --yes
npx draftie list
```

`delete` erases the page and every version, and nothing can bring it back. Run it only when the
user asks.
