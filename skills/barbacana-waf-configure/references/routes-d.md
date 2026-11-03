# Per-team `routes.d` files

## Status: not supported

The schema doc describes a `routes.d/*.yaml` directory, one `routes:` list per file, with `routes_dir:` to change its location. **No release loads it.** v0.10.0 rejects `routes_dir` at validation ("not supported yet; define every route under routes"). v0.9.7 accepted the key and silently never read the directory: a route placed there got no route and no protection, and `--validate` printed `config valid`.

So:
1. Do not tell the user per-team files work. If their config already has `routes_dir` or a `routes.d/` directory, point it out: on v0.10.0 the config will not validate, and on v0.9.7 those routes are silently missing.
2. Offer the working alternatives:
   - keep all routes in one `waf.yaml`, with a comment per team (`# owner: payments`) and CODEOWNERS on the repository for that file;
   - keep per-team YAML fragments in the repository and have CI concatenate them into `waf.yaml` (the build step is the user's; then run `--validate` on the result in CI). Offer to write the script; do not invent a Barbacana feature for it.
3. Ordering decides which route wins (see `routes-and-matching.md`), so do not let two teams own overlapping paths, however the file is assembled.
4. If a later release adds the feature, its release notes and `--validate` will say so; follow those, not this file.
