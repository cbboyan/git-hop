# git-hop

Automatically sync your git repositories when you sit down at a machine — and store them when you leave.

`git-hop` is a systemd service that runs `git pull` at login and `git push` at logout, keeping your repos in sync across all your devices with zero manual effort.

## The idea

You work on one machine at a time. When you arrive, your repos are already up to date. When you leave, your work is safely stored in the remote. No manual commits, no forgetting to push.

At login, `git-hop` fetches the remote state and brings the local repo up to date (fast-forward, merge, or push pending commits as needed). At logout, it commits any local changes and pushes. If there is no network, local work is always committed first — it will be pushed next time.

This model works best with **exclusive use**: only one of your devices active at a time. Occasional overlap is handled gracefully — `git-hop` will merge where possible and report conflicts clearly.

## Requirements

- Linux with systemd
- Git repos with a configured remote (`origin`)
- SSH key (or credential helper) that allows passwordless push/pull
- [ntfy](https://ntfy.sh) (optional, for push notifications)

## Configuration

### Repos

Create `~/.config/git-hop/repos` with one repo per line. Each line is a whitespace-separated `dir url` pair (dir relative to your home directory):

```
repos/myproject    git@github.com:you/myproject.git
repos/notes        git@github.com:you/notes.git
documents/journal  git@github.com:you/journal.git
```

Or use `git-hop add` to register repos from the command line:

```sh
git-hop add ~/repos/myproject
```

### Notifications (optional)

To receive push/pull notifications via [ntfy.sh](https://ntfy.sh), set `NTFY_CHANNEL` in `~/.config/git-hop/config`:

```sh
NTFY_CHANNEL=your-channel-name
```

Then subscribe to that channel in the ntfy app or browser. Notifications include the hostname and a per-repo summary (e.g. `notes(pulled), dotfiles(merged) | 2 up-to-date`).

## Installation

```sh
make install   # install binary and service file
make enable    # enable lingering, enable and start the service
```

See [INSTALL.md](INSTALL.md) for troubleshooting and all Makefile targets.

## Commands

```sh
git-hop pull              # pull all repos (run at login by the service)
git-hop push              # commit and push all repos (run at logout by the service)
git-hop status            # one-line status per repo
git-hop list              # list configured repos
git-hop add <dir>         # add a repo to the config
git-hop log               # show journal log (accepts journalctl args)
git-hop service           # show systemd service status
```

## License

[CC0 1.0 Universal](LICENSE) — public domain, no rights reserved.
