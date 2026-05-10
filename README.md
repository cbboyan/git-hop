# 🐇 git-hop

> Sit down. Your repos are already up to date. Get up. Your work is already pushed.

`git-hop` is a systemd user service that automatically pulls your git repositories at login and pushes them at logout — keeping everything in sync across all your machines with zero manual effort.

## ✨ The idea

You work on one machine at a time. When you arrive, `git-hop` has already fetched and merged the latest changes. When you leave, it commits whatever you were working on and pushes it safely to the remote. No manual commits. No forgetting to push. No stale code waiting on another machine.

At **login**, `git-hop` fetches the remote state and brings each repo up to date — fast-forward, merge, or push pending local commits as needed. Repos that are missing locally (e.g. on a freshly set up machine) are cloned automatically.

At **logout**, it commits any uncommitted changes first — so local work is never lost even without a network — then fetches, merges if needed, and pushes.

Occasional overlap between devices is handled gracefully: `git-hop` merges where possible and reports conflicts clearly with desktop and push notifications.

## 📋 Requirements

- 🐧 Linux with systemd
- 🔑 SSH key (or credential helper) for passwordless push/pull
- 📡 [ntfy](https://ntfy.sh) _(optional)_ — push notifications on your phone or browser
- 🔔 `libnotify` / `notify-send` _(optional)_ — desktop notifications

## ⚡ Installation

No root required — `git-hop` installs entirely under your home directory.

```sh
git clone https://github.com/cbboyan/git-hop.git
cd git-hop
make install   # installs to ~/.local/bin/ and ~/.config/systemd/user/
make enable    # enables lingering and starts the service
```

See [INSTALL.md](INSTALL.md) for troubleshooting and all Makefile targets.

## 🗂️ Adding repos

Register an existing local repo:

```sh
git-hop add ~/repos/myproject
```

Or clone a remote and register it in one step:

```sh
git-hop clone git@github.com:you/myproject.git
```

For manual editing, add `dir url` pairs to `~/.config/git-hop/repos` (one per line). The directory can be relative to `$HOME`, prefixed with `~/`, or an absolute path:

```
repos/myproject    git@github.com:you/myproject.git
~/repos/notes      git@github.com:you/notes.git
/opt/myproject     git@github.com:you/other.git
```

Any repo listed in the config that doesn't exist locally will be cloned automatically on the next login — handy when setting up a new machine.

## 🔔 Notifications

### Desktop

Desktop notifications appear at login and logout via `notify-send` (part of `libnotify`). They are skipped automatically if `notify-send` is not installed. To disable explicitly, set in `~/.config/git-hop/config`:

```sh
GITHOP_DESKTOP=no
```

### Phone / browser (ntfy)

To receive notifications on your phone or in the browser via [ntfy.sh](https://ntfy.sh), set your channel in `~/.config/git-hop/config`:

```sh
GITHOP_NTFY_CHANNEL=your-channel-name
```

Then subscribe to that channel in the ntfy app or at [ntfy.sh](https://ntfy.sh). Notifications include the hostname and a per-repo summary — e.g. `notes pulled, dotfiles merged | 2 up-to-date`.

## 🛠️ Commands

| Command | Description |
|---|---|
| `git-hop pull` | Pull all repos _(run at login by the service)_ |
| `git-hop push` | Commit and push all repos _(run at logout by the service)_ |
| `git-hop status` | One-line status for each repo |
| `git-hop list` | List configured repos |
| `git-hop add <dir>` | Add an existing repo to the config |
| `git-hop clone <url>` | Clone a repo and add it to the config |
| `git-hop log` | Show journal log _(accepts journalctl args)_ |
| `git-hop service` | Manage the systemd service _(start/stop/enable/disable/status)_ |

## 📝 Changelog

### v0.9.1
- Added: auto-clone repos missing locally (e.g. fresh machine setup)
- Added: `clone` subcommand
- Added: support for `~/` and absolute paths in repos config
- Added: desktop notifications with icon, app name, transient flag, graphical session detection, and `GITHOP_DESKTOP` config option
- Added: detect unfinished git operations (merge, rebase, cherry-pick) before acting
- Added: `service` subcommand supports start/stop/enable/disable (not just status)
- Added: `log` shows current boot only by default
- Fixed: no-network login showed a false success notification (bash `local var=$(cmd)` always exits 0)
- Improved: notification says "no network" instead of "check journal" when offline
- Improved: warning notifications persist in the tray until dismissed

### v0.9.0 — initial release
- Pull at login: stash dirty workdir, fetch, fast-forward / merge / push as needed
- Push at logout: commit first (local work never lost), fetch, merge if needed, push
- Push notifications via [ntfy](https://ntfy.sh)
- Basic desktop notification via `notify-send`
- Subcommands: `pull`, `push`, `status`, `list`, `add`, `service`, `log`

## 📄 License

[CC0 1.0 Universal](LICENSE) — public domain, no rights reserved.
