# Verify and upgrade

## Verify the image (optional, recommended for production)

Needs `cosign` 3.0 or newer.

```bash
cosign verify \
  --certificate-identity='https://github.com/barbacana-waf/barbacana/.github/workflows/release.yml@refs/heads/master' \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/barbacana-waf/barbacana:vX.Y.Z
```

Success prints verified signatures and exits 0. Use this exact identity, not a regex: releases are signed by the `release.yml` workflow on `master`, so a tag-based pattern fails. (Verified against v0.9.7.) If `cosign` is missing, say so and skip; do not install tools without asking. Edge images are unsigned, so verification fails for them by design.

Binaries: verify `checksums.txt` with `cosign verify-blob --bundle checksums.txt.bundle checksums.txt` using the same `--certificate-identity` and `--certificate-oidc-issuer` flags, then check the archive with `sha256sum --check --ignore-missing checksums.txt` (macOS: `shasum -a 256 -c`). Verified against v0.9.7.

## Upgrade

1. Read `CHANGELOG.md` between the current and target version in the release notes. Config keys, protection names and metrics follow semver; deprecated items warn at startup for at least a release before removal.
2. Run `--validate` with the **new** version against the existing config before switching.
3. Change the pinned tag (compose file, Deployment image, or binary), then restart or roll out.
4. Re-run the smoke test.

## Roll back

Restore the previous tag or binary and restart. The service is stateless apart from `data_dir` (TLS certificates), so rollback needs nothing else.
