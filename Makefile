BINDIR    = $(HOME)/.local/bin
SYSTEMDIR = $(HOME)/.config/systemd/user
CONFDIR   = $(HOME)/.config/git-hop

install:
	mkdir -p $(BINDIR) $(SYSTEMDIR) $(CONFDIR)
	install -m 755 git-hop.sh $(BINDIR)/git-hop
	install -m 644 git-hop.service $(SYSTEMDIR)/git-hop.service
	[ -f $(CONFDIR)/config ] || install -m 644 config $(CONFDIR)/config
	systemctl --user daemon-reload
	@echo "Installed. Run 'make enable' to start the service."

uninstall: disable
	rm -f $(BINDIR)/git-hop
	rm -f $(SYSTEMDIR)/git-hop.service
	systemctl --user daemon-reload

enable:
	loginctl enable-linger $(USER)
	systemctl --user enable git-hop
	systemctl --user start git-hop

stop:
	systemctl --user stop git-hop

disable: stop
	systemctl --user disable git-hop

status:
	systemctl --user status git-hop

.PHONY: install uninstall enable stop disable status
