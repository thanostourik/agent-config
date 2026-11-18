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

- `--visibility public` lets anyone with the link open the draft. The default, `private`, is only the user. Use `public` only when the user wants someone else to open it.
- `--expires 7d` deletes the draft after that time: `30m`, `12h`, `2w`, or `never`.
- `--new` uploads the file as a new draft instead of a new version.

Draftie groups drafts by the git repository holding the draft, or the one `draftie upload` runs in. When no git repository is found, drafts go under "No repository".

If it fails with "an upload needs an API key", tell the user to run `npx draftie auth login`. Only they can sign in.

If it fails with "this HTML holds …", tell the user what the message names. Do not change the file.

## Read a draft from a link

```sh
npx draftie get '<link>'
```

Use this, not a browser or web fetch. A private draft needs the API key, and only the CLI sends it.

## Change or delete a draft

`<draft>` is the uploaded file, the draft's link, or its id.

```sh
npx draftie set <draft> --visibility public
npx draftie list
npx draftie delete <draft> --yes
```

Run `delete` only when the user asks. It erases every version.
