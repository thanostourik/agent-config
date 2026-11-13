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
- **Why the source search is enough:** routes are files.
  `.next/app-path-routes-manifest.json` adds only Next's own pages, such as `/_not-found`.

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
  the run's app log.

## Drupal

- **How to tell:** `drupal/core` or `drupal/core-recommended` in `composer.json`.
- **Entry points:** ask the run's site through drush. Views, webforms and routes that
  modules add at run time live in configuration and the database, where a source search
  misses them.
  - Every route with its handler:
    `drush php:eval 'foreach (\Drupal::service("router.route_provider")->getAllRoutes() as $n => $r) { $d = $r->getDefaults(); echo implode(",", $r->getMethods() ?: ["GET"]), " ", $r->getPath(), "\t", isset($d["view_id"]) ? "view:" . $d["view_id"] : ($d["_controller"] ?? $d["_form"] ?? $d["_entity_form"] ?? $d["_entity_list"] ?? ""), "\n"; }'`.
  - Every webform a visitor can open:
    `drush php:eval 'foreach (\Drupal::entityTypeManager()->getStorage("webform")->loadMultiple() as $id => $w) if ($w->isOpen() || $w->isScheduled()) echo "/webform/$id\t", $w->label(), "\n";'`.
  - Keep the routes whose handler is a View, a webform or a class of a custom module or
    theme.
  - Drush prints PHP deprecation notices on stdout. Give the lines the script prints a
    prefix and keep only those.
- **Files:**
  - The file of a class `\Drupal\<module>\<path>\<Class>` is
    `modules/custom/<module>/src/<path>/<Class>.php` (or `themes/custom/...`).
  - The file of a View is `config/sync/views.view.<id>.yml`, and of a webform
    `config/sync/webform.webform.<id>.yml`.
  - A webform kept only in the database has no file. The script writes its definition
    (`drush config:get webform.webform.<id>`) to the skill's
    `.cache/entry-files/webform.webform.<id>.yml` and prints that path from the repository
    root. `bin/areas` then groups it, and its recorder reads its fields there.
- **What it adds:** on one site the router listed 192 open webforms, where a search of
  the source found 1. It also listed 75 View pages. Each command took under a second.
- **Still not listed:** blocks placed in layouts or regions, and Layout Builder content.
  They render on pages that the routes above already list.
