# git-hop TODO

## 📌 Should — before public release

_(nothing blocking — ready for public release)_

## 💡 Nice to have

- **service split:** replace the current `git-hop.service` with four focused services, each independently installable:
  - `git-hop-power.service` — pull at boot / push at shutdown (`default.target`); for servers and desktops that reboot rather than log out; no desktop notifications (ntfy only)
  - `git-hop-desktop.service` — pull at first graphical login / push at shutdown (`graphical-session.target` + `RemainAfterExit`); full desktop notifications; current `git-hop.service` behaviour
  - `git-hop-login.service` — pull on every graphical login / push on every graphical logout; D-Bus watcher (see below) listening for logind session events (`SessionNew`/`SessionRemoved` on `org.freedesktop.login1.Manager`); same Python watcher as suspend, extended to handle both
  - `git-hop-suspend.service` — push before suspend / pull on resume; Python D-Bus watcher with `delay` inhibitor lock (see below); works alongside any of the above
  - Makefile gets `install-boot`, `install-desktop`, `install-login`, `install-suspend` targets (plus `install-all`)

- **suspend/resume + login/logout watcher** (`git-hop-suspend.service`, `git-hop-login.service`): `Type=simple` user services running a Python script that listens for logind D-Bus signals — `PrepareForSleep` for suspend/resume (with `delay` inhibitor lock to guarantee push completes before suspend), and `SessionNew`/`SessionRemoved` for login/logout. Could be one shared watcher script with flags, or two separate scripts. Requires `python3-dbus` and `python3-gobject`. Shutdown already handled by `ExecStop` — inhibitor only needed for suspend.

- **network timeout:** on weak wifi, `git fetch` can hang for minutes per repo. Fix with (a) a pre-flight inet check (`nc -zw2 8.8.8.8 53`) to bail early when there's no network, and (b) `timeout N` on `git_fetch` as a safety net. Make check host configurable via `INET_CHECK_HOST` in config. Not blocking — user service runs in background and doesn't delay login.

- **periodic push:** push while running (idle detection or fixed interval, e.g. every hour).

## 🧪 Testing — before public release

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

## ✅ Done

- **unfinished git operation detection:** `git_check_state()` checks for MERGING, CHERRY-PICKING, REVERTING, and REBASING states before any git operations in pull/push — prevents committing files with conflict markers.
- **desktop notification styling:** split into summary/body lines; icons (`emblem-default`, `dialog-error`, `dialog-warning`); `-u critical` for errors (stays until dismissed); `-e` transient for normal notifications (no notification center clutter); app name via `-a`; markdown stripped.
- **desktop notification reliability:** `DBUS_SESSION_BUS_ADDRESS` set in service file; `After=WantedBy=graphical-session.target` so pull runs after the desktop session is up.
- **desktop notifications configurable:** `GITHOP_DESKTOP=no` to disable; auto-skipped if `notify-send` not installed.
- **absolute path support:** repo dirs in config can be relative to `$HOME`, prefixed with `~/`, or full absolute paths. `add` stores full path for repos outside `$HOME`.
- **auto-clone missing repos:** repos in config that don't exist locally are cloned automatically on pull — useful on a freshly set up machine.
- **`git-sync` investigated** — unrelated (git-extras), destructively resets branch to remote. Not usable.
- **name:** `git-store` taken on GitHub and npm. `git-hop` chosen — clear on all registries.
- **rename:** files and references updated from `gitsync` to `git-hop`.
- **config:** `~/.config/git-hop/repos`, whitespace-separated `dir url` pairs. `~/.config/git-hop/config` sourced as `KEY=value`. Default config included in repo, copied on install only if not already present.
- **sync logic:** login = stash dirty workdir → fetch → detect state (even/behind/ahead/diverged) → act → pop stash. logout = commit first → fetch → detect state → merge if needed → push. Commit-before-fetch ensures local work is never lost.
- **error channels:** `logger -p user.err` (journal), ntfy (remote), `notify-send` (desktop).
- **refactor:** `log_`/`ntfy_`/`git_` function prefixes; `repos()` centralises config parsing; `git_fetch()` combines fetch + state detection; `run_repos()` eliminates duplicated loop; `log_summary()` unifies push/pull notification.
- **log:** interactive output via stderr (`[ -t 2 ]`), persistent via `logger` to journal.
- **per-repo results:** `RESULT` set by `pull`/`push` to `up-to-date`/`pulled`/`pushed`/`merged`/`cloned`; `summarize()` builds summary message.
- **subcommands:** `add`, `list`, `status`, `service`, `log`, `clone`.
- **Makefile:** `install`/`uninstall`/`enable`/`stop`/`disable`/`status` targets.
- **license:** CC0 1.0 Universal (public domain).
