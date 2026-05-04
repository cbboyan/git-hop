## done

- `git-sync` (git-extras) investigated — unrelated, destructively resets branch to remote. Not usable.
- name: `git-store` taken on GitHub and npm. `git-hop` chosen — clear on all registries.
- rename: files and references updated from `gitsync` to `git-hop`.
- config: `~/.config/git-hop/repos`, whitespace-separated `dir url` pairs, parsed with `while read DIR URL`.
- ntfy channel: `~/.config/git-hop/config` sourced as `KEY=value`; `NTFY_CHANNEL` sets the ntfy topic. Notifications skipped silently if unset.  default `config` file included in repo, copied on install.
- invariant and sync logic: login = fetch → detect state (even/behind/ahead/diverged) → act; logout = commit first → fetch → detect state → merge if needed → push.  errors logged via `logger -p user.err`, ntfy, and `notify-send` (desktop).  stash on dirty workdir at login.
- refactor: lowercase function names; `log_info`/`log_err`/`log_ntfy`/`log_desktop` output channels; no underscores except `log_` prefix; `repos()` centralises config parsing; `fetch()` combines git fetch + state detection.
- log file dropped: interactive output via stderr (`[ -t 2 ]`), persistent record via `logger` to journal.
- per-repo status and summary: `RESULT` set by `pull`/`push` to `up-to-date`/`pulled`/`pushed`/`merged`; `summarize()` builds message like "notes(pulled), dotfiles(merged) | 2 up-to-date".
- `add` subcommand: resolves path, validates git repo, extracts origin URL, checks not already in config, appends to `~/.config/git-hop/repos`.
- `list`, `status` (one-line per repo), `service`, `log` subcommands added.  `status` shows `up-to-date` when clean.
- Makefile: install/uninstall/enable/stop/disable/status.  `install` copies `git-hop.sh` → `~/.local/bin/git-hop`.  `enable` runs `loginctl enable-linger`.
- license: CC0 1.0 Universal (public domain).
- ntfy messages: include hostname, pull vs. push action, per-repo details with result summary.

## testing — before public release

**Setup tip:** `systemctl --user stop git-hop` prevents the service from auto-running so you can trigger `git-hop pull` / `git-hop push` manually and control timing precisely. To simulate a dirty workdir at boot, stop the service on machine A, make local edits without committing, then reboot (or run `git-hop pull` manually).

**Pull scenarios (simulate boot on machine A):**
- [ ] behind remote: machine B pushes while A is off → boot A → expect fast-forward
- [ ] ahead of remote: A commits offline (no network at last shutdown) → boot A with network → expect push
- [ ] diverged, non-conflicting: A has offline commit, B pushed different file → boot A → expect merge + push
- [ ] diverged, conflicting: A has offline commit, B pushed conflicting change → boot A → expect merge conflict error + ntfy
- [ ] dirty workdir + remote ahead: stop service on A, edit a file, boot A while B has pushed → expect stash, merge, pop stash
- [ ] dirty workdir + stash pop conflict: stop service on A, edit file X; B pushes conflicting change to file X; boot A → expect stash pop conflict error + ntfy

**Push scenarios (simulate shutdown on machine A):**
- [ ] clean workdir, even with remote → expect no-op
- [ ] local changes, remote even → expect commit + push
- [ ] local changes, remote ahead, non-conflicting: stop service on A, edit file; B pushes different file; run `git-hop push` → expect commit + merge + push ✓
- [ ] local changes, remote ahead, conflicting: same but B edits same lines → expect merge conflict error + ntfy ✓
- [ ] no network: disconnect before `git-hop push` → expect local commit only + ntfy

## should — before public release

8. auto-clone: on pull, if a repo listed in config is missing locally, clone it from the stored URL.

## nice to have

11. periodic push: push while running (idle detection or fixed interval, e.g. every hour).
12. suspend/resume support: push before suspend, pull on resume. `sleep.target` is system-level so the cleanest hook needs root (system service drop-in); rootless alternative is listening on logind D-Bus `PrepareForSleep` signal via a second user service unit (`git-hop-sleep.service`).
13. graphical login/logout support: pull on graphical login via `graphical-session.target`, push on logout via `graphical-session-pre.target`. User-level, no root needed. Useful for setups that don't reboot but log out graphically. Would overlap with boot/shutdown service — needs a config flag or separate install target.
