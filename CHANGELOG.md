# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.0] - 2026-09-05

### Fixed
- **`curl | bash` no longer loops or hangs**: the child bash inherited the pipe
  as stdin, re-triggering the download branch and making every interactive
  `read` hit EOF. The script is now re-downloaded to a real file and re-run
  with the terminal as stdin.
- **SSH hardening now survives cloud-init**: settings are additionally written
  to a managed drop-in `/etc/ssh/sshd_config.d/00-vps-quickstart.conf`, because
  sshd uses the *first* occurrence of a directive and cloud-init's
  `50-cloud-init.conf` silently re-enabled `PasswordAuthentication` on many
  images.
- **SSH port detection** uses `sshd -T` (effective configuration); UFW and
  Fail2Ban now protect the port the daemon actually listens on — a wrong port
  here could lock you out.
- All interactive loops (main menu, submenus, port/size/username/password
  prompts) handle EOF and exit cleanly instead of spinning forever.
- Fail2Ban reports failure when the service is not running and installs
  `python3-systemd` (required by the systemd backend on Debian 12 minimal
  images).
- UFW no longer opens port 22 when SSH was moved to a custom port; the result
  of `ufw --force reset` is checked.
- Non-English system locales no longer break parsing (`LC_ALL=C`).
- Speed test / domain check: reliable endpoints, 2xx–3xx treated as reachable,
  dig availability checked, domain format validated.
- Swap: dangling `/etc/fstab` entry is removed if the swap file creation fails.
- IPv6 status no longer shows a stale cached public address.
- BBR: unrelated sysctl drop-in errors no longer abort the feature.
- User creation: SSH public keys are validated before writing, `chpasswd`
  result is checked with rollback on failure.
- Log file is created after the root check with 600 permissions; the logger
  tolerates an unwritable log.
- Repository URLs in the script header no longer point to a placeholder.

### Changed
- Utility/log messages (~25 of them) now use the existing i18n keys, so
  Russian users get a fully translated output.
- Dead i18n keys removed (30 unused + duplicated RU block); new keys added for
  all new messages; EN and RU key sets are identical.
- Base packages are installed in a single `apt-get` transaction instead of 15
  sequential runs, with a per-package retry fallback.
- `apt` runs with `DEBIAN_FRONTEND=noninteractive` and `--force-confold` so it
  never blocks on interactive prompts.
- 3x-ui post-install info shows the real generated credentials (from
  `/etc/x-ui/install-result.env` when present) instead of hardcoded
  `admin/admin:2053`.
- `sysctl --system` failures unrelated to BBR are warnings, not aborts.

### Added
- `-h/--help` and `-V/--version` command-line flags.
- GitHub Actions CI: `bash -n`, shellcheck (errors only) and an i18n key
  consistency gate (used ⊆ defined, EN == RU).
- `.gitattributes` enforcing LF for shell scripts.
- `CHANGELOG.md` (this file).

## [1.1.0] - 2025

- Production-ready release: README, LICENSE, code review fixes, Russian
  language support with a full i18n system.

## [0.1.0] - 2024

- Initial release: interactive menu with 15 setup/maintenance features for
  Debian/Ubuntu VPS.
