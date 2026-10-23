# Per-team `routes.d` files

## Status in v0.9.7: not loaded

The schema doc describes a `routes.d/*.yaml` directory, one `routes:` list per file, with `routes_dir:` to change its location. **The v0.9.7 binary accepts `routes_dir` but never reads the directory.** Verified: with `routes_dir: ./routes.d` and a file there defining a route with an invalid protection name, `--validate` printed `config valid` and `--render-config` contained none of its routes. The `master` source has no loader for it either (only the key and its default exist).

So, until a release says otherwise:
1. Do not tell the user per-team files work. A route placed in `routes.d/` is silently ignored, which means that team's traffic gets no route and no protection.
2. Check first: add a throwaway route to a `routes.d` file and look for its `id` in `--render-config`. Drop it after the check. Or ask the user which release notes mention `routes.d`.
3. Offer the working alternatives:
   - keep all routes in one `waf.yaml`, with a comment per team (`# owner: payments`) and CODEOWNERS on the repository for that file;
   - keep per-team YAML fragments in the repository and have CI concatenate them into `waf.yaml` (build step is the user's, then run `--validate` on the result in CI). Offer to write the script; do not invent a Barbacana feature for it.
4. If the user's Barbacana prints a newer version where the render shows routes from `routes.d`, follow the semantics below.

## Intended semantics (from the design doc, unverified on a release)

- Default directory `routes.d/` beside the main file, or `routes_dir`.
- Files load in lexical order; route ids must be unique across all files; a `global:` key in a file is an error; a parse error in one file fails the whole load.
- Because ordering decides which route wins (see `routes-and-matching.md`), do not let two teams own overlapping paths.
