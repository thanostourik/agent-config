# Entry points by framework

`bin/entrypoints.sh` lists every entry point as `<entry point><TAB><file>`. For a framework
below, it lists them the way its section says. Any other project uses a search over the
source: route annotations, router files, command definitions.

A framework that builds entry points at run time, from configuration or the database, is
asked through the run's own environment, never the developer's. When the run is down, the
script falls back to the source search and says so on stderr, so `verify uncovered` and
`verify affected` still work.

Add a framework here only after its command ran on a real project.

## Next.js (app router)

- **How to tell:** `next` in `package.json` and an `app/` folder.
- **Entry points:** each `page.*` file is a screen and each method a `route.*` file exports
  is an API route. The URL is the folder path without `(group)` segments; a dynamic segment
  keeps its brackets (`/tenants/[tenantId]`).
- **Why the source search is enough:** routes are files. On one project the search found
  the same 72 routes as `.next/app-path-routes-manifest.json`, which adds only Next's own
  pages such as `/_not-found`.

## Spring MVC

- **How to tell:** `spring-boot-starter-web` or `spring-webmvc` in the build file.
- **Entry points:** search the source for `@GetMapping`, `@PostMapping`, `@PutMapping`,
  `@PatchMapping`, `@DeleteMapping` and `@RequestMapping`, joining a class's path to its
  methods' paths.
- **When the source search misses routes:** a project that also maps URLs in code
  (`RouterFunction`, `SimpleUrlHandlerMapping`, a bean that maps paths to page classes)
  starts the run's app with
  `-Dlogging.level._org.springframework.web.servlet.HandlerMapping.Mappings=debug`.
  At startup Spring then logs every mapping under its class, one per line:
  `{GET [/api/v1/abbreviations]}: getAbbreviations()`. The script reads those lines from
  the run's app log. On one project the log listed the same 175 routes as the annotations,
  8 s after start.
