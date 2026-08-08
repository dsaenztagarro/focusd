# focusd — build, install as a LaunchAgent, and manage the running daemon.
#
#   make build      compile the release binary
#   make install    build, install the binary + LaunchAgent, and (re)load it
#   make reload      alias for install (rebuild + relaunch after code changes)
#   make logs        tail the daemon log
#   make uninstall   unload the LaunchAgent and remove the binary
#   make clean       remove build artifacts

LABEL     := local.focusd
BIN_NAME  := focusd

BINDIR    := $(HOME)/.local/bin
INSTALLED := $(BINDIR)/$(BIN_NAME)
BUILT     := .build/release/$(BIN_NAME)

PLIST_SRC := launchd/$(LABEL).plist
PLIST_DST := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG       := $(HOME)/Library/Logs/$(LABEL).log

.PHONY: build install reload uninstall logs run clean

build:
	swift build -c release

install: build
	@mkdir -p $(BINDIR) $(HOME)/Library/LaunchAgents
	cp $(BUILT) $(INSTALLED)
	# Fill the absolute paths launchd needs (it won't expand ~).
	sed -e 's#__BIN__#$(INSTALLED)#g' -e 's#__LOG__#$(LOG)#g' $(PLIST_SRC) > $(PLIST_DST)
	@touch $(LOG)
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	launchctl load $(PLIST_DST)
	@echo "Installed and loaded $(LABEL). Press Ctrl+T to toggle."

reload: install

uninstall:
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	rm -f $(PLIST_DST) $(INSTALLED)
	@echo "Uninstalled $(LABEL)."

logs:
	@touch $(LOG); tail -f $(LOG)

# Run in the foreground for debugging (Ctrl-C to stop).
run: build
	$(BUILT)

clean:
	swift package clean
	rm -rf .build
