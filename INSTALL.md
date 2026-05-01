# git-hop Installation

## Install

```sh
make install
```

Copies `git-hop` to `~/.local/bin/`, the service file to `~/.config/systemd/user/`, and the default config to `~/.config/git-hop/config` (only if not already present).

## Enable

```sh
make enable
```

Enables lingering (so the service starts at boot, not just on login), then enables and starts the service.

## Other targets

```sh
make stop       # stop the service
make disable    # stop and disable the service
make uninstall  # remove the binary and service file
make status     # show service status
```

---

## Troubleshooting

Check the log:

```sh
git-hop log
git-hop log -n 50
git-hop log --since today
```

Or directly via journalctl:

```sh
journalctl --user -t git-hop
```

Check for SELinux denials:

```sh
sudo ausearch -m avc -ts recent
```

If SELinux blocks execution of `git-hop`, label it as executable:

```sh
FILE=$(readlink -f ~/.local/bin/git-hop)
sudo setenforce 0
sudo semanage fcontext -a -t bin_t $FILE
sudo restorecon -vF $FILE
sudo setenforce 1
```
