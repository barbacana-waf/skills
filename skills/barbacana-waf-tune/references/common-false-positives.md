# Typical causes

Starting points only. The audit log decides; confirm every name with `barbacana --catalog-leaf`. Examples below come from the v0.9.7 catalog's "when to toggle" text.

| App feature | Looks like | Often matched | Better first move |
|---|---|---|---|
| Free-text search over prose or code | SQL words (`and`, `or`, `like`, `select`, `union`) in a query | operator, union/select, function-call leaves | scope the exception to the search route only |
| Markdown or rich-text editor | backticks, `--`, `#`, `/* */` | backtick and SQL-comment leaves | scope to the editor's save route |
| Code or SQL snippets (docs, playground) | function names, concat operators | function-call, concatenation leaves | scope to those routes; never global |
| Multi-key JSON API bodies | `, "key":` patterns | the aggressive JSON-comment leaf (off by default) | remove it from `enable`; do not add a disable |
| Binary or hash fields echoed in text | long hex strings | hex-encoded leaf | scope to that field's route |
| Unusual clients | missing `Accept`/`User-Agent` | the two header checks (off by default) | remove from `enable` |

If the matched protection is not an injection check (size, content type, method, OpenAPI validation), the answer is a route `accept` or `openapi` setting, not a `disable`.

Never conclude "false positive" from the payload alone. In testing, a plain search phrase containing "union select" was blocked by an MSSQL-specific leaf, not by the union/select leaf a reader would guess.
