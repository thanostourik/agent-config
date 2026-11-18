---
name: draftie
description: Use when the user asks to upload, publish, or share an HTML file through draftie, or gives a draftie link (path starts with /api/d/).
---

# draftie

## Upload

```sh
npx draftie upload <file>
```

Give the user the `URL:` line it prints. Uploading the same file again adds a version at the same link.

- `--visibility public` lets anyone with the link open the page. The default, `private`, is only the user. Use `public` only when the user wants someone else to open it.
- `--expires 7d` deletes the page after that time: `30m`, `12h`, `2w`, or `never`.
- `--new` uploads the file as a new page instead of a new version.

If it fails with "an upload needs an API key", tell the user to run `npx draftie auth login`. Only they can sign in.

If it fails with "this HTML holds …", tell the user what the message names. Do not change the file.

## Read a page from a link

```sh
npx draftie get '<link>'
```

Use this, not a browser or web fetch. A private page needs the API key, and only the CLI sends it.

## Change or delete a page

`<page>` is the uploaded file, the page's link, or its id.

```sh
npx draftie set <page> --visibility public
npx draftie list
npx draftie delete <page> --yes
```

Run `delete` only when the user asks. It erases every version.
