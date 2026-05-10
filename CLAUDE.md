# git-hop

Public GitHub repo. Previously named `gitsync`, renamed to `git-hop`.

## What it does

`git-hop` is a systemd user service that automatically pulls git repos at login and pushes them at logout. Designed for a single user across multiple devices. At login it fetches, detects state (even/behind/ahead/diverged), and acts accordingly. At logout it commits first (always), then fetches, merges if needed, and pushes.

## Files

- `git-hop.sh` — main script; installed as `git-hop` (no `.sh` extension in PATH)
- `git-hop.service` — systemd user service (`%h/.local/bin/git-hop pull/push`)
- `config` — default config template; copied to `~/.config/git-hop/config` on install (only if not already present)
- `Makefile` — install/uninstall/enable/stop/disable/status targets
- `INSTALL.md` — installation and troubleshooting
- `TODO.md` — active TODO list

## Changelog

- Maintained in `README.md` under `## 📝 Changelog`, newest version first.
- Each release has a `### vX.Y.Z` heading; initial release appends `— initial release`.
- Entries use `Added:` / `Fixed:` / `Improved:` prefixes. Keep only significant features and fixes — omit minor details.
- When making changes between releases, add an `### Unreleased` section at the top and accumulate entries there. On release, rename it to the version heading.
- Version is tracked via git tags (`vX.Y.Z`) — no version variable in the source. Tags are pushed explicitly with `git push origin vX.Y.Z`. Version is bumped occasionally, not on every commit; patch for fixes/small improvements, minor for notable feature additions.

## Subcommands

`pull`, `push`, `status`, `list`, `add <dir>`, `service`, `log`

## Configuration

- `~/.config/git-hop/repos` — `dir url` pairs, whitespace-separated, dir relative to `$HOME`; blank lines and `#` comments ignored
- `~/.config/git-hop/config` — sourced as shell `KEY=value`; `GITHOP_NTFY_CHANNEL` sets ntfy topic

## Design decisions

- Source scripts use `.sh` extension in the repo; installed to PATH without extension via `make install`.
- Backticks used in shell scripts — do not convert to `$()`.
- `git-sync` (git-extras) is unrelated — destructively resets branch to remote.
- `git-store` name taken on GitHub and npm; `git-hop` is clear on all registries.
- Login flow: stash dirty workdir → fetch → state → act → pop stash. Fetch failure = no network, skip gracefully.
- Logout flow: commit first → fetch → state → merge if needed → push. Commit-before-fetch ensures local work is never lost.
- Three error channels: `logger -p user.err` (journal), ntfy (remote), `notify-send` (desktop).
- Function naming: group related functions with a common prefix (`log_`, `ntfy_`, `git_`); one word after the `_` (e.g. `log_info`, `ntfy_send`, `git_push`); hierarchy allowed (`log_debug`, `ntfy_err`). Top-level subcommand functions (`pull`, `push`, `status`, etc.) need no prefix.
- `log_err` — journal only; `log_error` — full broadcast (journal + ntfy + desktop), used for critical errors requiring manual intervention.
- `git_` functions wrap git operations with debug log redirect; call these from `pull`/`push` instead of raw git, except trivial one-liners in conditionals (e.g. `git status --porcelain`).
- `log_info`/`log_err` echo to stderr only when interactive (`[ -t 2 ]`) to avoid duplicate journal entries from the service.
- System-wide service dropped — user services are standard; system service required root and hardcoded the username.
- License: CC0 1.0 Universal (public domain, no attribution required).
