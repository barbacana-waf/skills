# Bare binary with systemd

Release archives are on the GitHub release page: `barbacana_<version>_<os>_<arch>.tar.gz` for linux/darwin (zip for windows), amd64 and arm64, plus `checksums.txt` and `checksums.txt.bundle`.

1. Detect OS and architecture (`uname -sm`), pick the matching archive for the pinned version.
2. Download the archive and `checksums.txt`; verify with `sha256sum --check --ignore-missing checksums.txt`. For production, also verify the signature (`references/verify-and-upgrade.md`).
3. Install the `barbacana` binary to `/usr/local/bin`. Create a `barbacana` user and `/etc/barbacana/waf.yaml`.
4. Set `data_dir: /var/lib/barbacana` in the config (matches `StateDirectory=` in the unit).
5. Install `assets/barbacana.service` as `/etc/systemd/system/barbacana.service`. `ExecStartPre` runs `--validate`, so a bad config stops the start instead of taking the service down on reload.
6. `systemctl daemon-reload && systemctl enable --now barbacana`; check `systemctl status barbacana` and `journalctl -u barbacana`.

`CAP_NET_BIND_SERVICE` is needed only for ports below 1024 (auto-TLS). The unit file is a starting point and was not run under systemd in testing.
