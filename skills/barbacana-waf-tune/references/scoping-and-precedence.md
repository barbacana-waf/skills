# Scoping a change

## The catalog is a tree

Three levels, all valid in `disable` and `enable`: a family (`sql`), a bucket (`sql-injection`), a leaf (`sql-injection-mssql-specific`). Use `barbacana --catalog` for the current tree and `--catalog-leaf <id>` for one leaf's description and "Why disable" text. Choose the leaf the audit log named.

## Precedence

For each leaf, the effective state is decided by the four lists `global.disable`, `global.enable`, `route.disable`, `route.enable`:

1. A leaf-level entry beats a bucket or family entry that covers it.
2. A bucket entry beats a family entry.
3. At equal specificity a route entry beats a global one.

So `disable: [<leaf>]` on a route overrides a global `enable` of its bucket, and a leaf `disable` survives a bucket `enable`. The same ID in both `disable` and `enable` of one route is a config error.

An `enable` of something already on, or a `disable` of something already off, is a harmless no-op.

## Route or global?

Put the change on the route that needs it. The route's `id` is what shows in the audit log (`route`), and route matching is path-first: a route with a narrower `match.paths` wins over a catch-all, so a new route for one endpoint isolates the exception. Confirm after the change that the audit event for that endpoint shows the new route id.

```yaml
routes:
  - id: search                       # new, narrow
    match: {paths: ["/search*"]}
    upstream: http://shop:8000
    # Search box legitimately contains SQL words. Gives up: <what the leaf catches>. 2026-10-22
    disable: [sql-injection-mssql-specific]
  - id: shop                         # existing catch-all keeps every protection
    upstream: http://shop:8000
```

## Default-off protections

Some leaves ship off because they cause false positives or have no safe default value (response header injection such as CSP, a couple of strict header checks, aggressive SQL variants). If a false positive follows a recent `enable`, remove that entry first. `--catalog` shows the default for each leaf.

## Changing mode

`mode: detect_only` can be set globally or per route. Prefer one route, for a short time, and set it back. In v0.9.7 neither `mode` nor `disable` edits are picked up by a SIGHUP reload; restart the process.
