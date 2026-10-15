# focusd — build, install as a LaunchAgent, and manage the running daemon.
#
#   make build      compile the release binary
#   make test       run the Swift Testing suite
#   make install    build, install the binary + LaunchAgent, and (re)load it
#   make reload      alias for install (rebuild + relaunch after code changes)
#   make logs        tail the daemon log
#   make pr-install PR=<n>  install pull request <n>'s build as the running agent
#   make pr-clean    remove the pull request checkouts pr-install made
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

# The commit being built, logged by focusd at start.
BUILD     := $(shell git describe --always --dirty 2>/dev/null || echo unknown)

# pr-install checks pull requests out under .build/, detached and throwaway.
PR_DIR    := $(CURDIR)/.build/pr-$(PR)

.PHONY: build test install reload uninstall logs run clean pr-install pr-clean

# The Command Line Tools ship the Swift Testing macro plugin outside the
# compiler's default plugin search path; point at it from the active toolchain.
TESTING_PLUGINS := $(abspath $(dir $(shell xcrun --find swift))../lib/swift/host/plugins/testing)
TEST_FLAGS      := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

install: build
	@mkdir -p $(BINDIR) $(HOME)/Library/LaunchAgents
	cp $(BUILT) $(INSTALLED)
	# Fill the absolute paths launchd needs (it won't expand ~), and the build.
	sed -e 's#__BIN__#$(INSTALLED)#g' -e 's#__LOG__#$(LOG)#g' -e 's#__BUILD__#$(BUILD)#g' $(PLIST_SRC) > $(PLIST_DST)
	@touch $(LOG)
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	launchctl load $(PLIST_DST)
	@echo "Installed and loaded $(LABEL) at $(BUILD). Press Ctrl+T to toggle."

reload: install

uninstall:
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	rm -f $(PLIST_DST) $(INSTALLED)
	@echo "Uninstalled $(LABEL)."

logs:
	@touch $(LOG); tail -f $(LOG)

# Run in the foreground for debugging (Ctrl-C to stop).
run: build
	FOCUSD_BUILD=$(BUILD) $(BUILT)

# Test a pull request the way it will ship: its own `make install`, under
# launchd, in place of the installed agent. `make install` on master restores
# the release.
pr-install:
	@test -n "$(PR)" || { echo "usage: make pr-install PR=<number>" >&2; exit 1; }
	git fetch origin pull/$(PR)/head
	git worktree remove --force $(PR_DIR) 2>/dev/null || true
	git worktree add --detach $(PR_DIR) FETCH_HEAD
	$(MAKE) -C $(PR_DIR) install
	@echo " PR $(PR) is the running focusd; back to the release: make install on master"

pr-clean:
	for dir in .build/pr-*; do [ -d "$$dir" ] && git worktree remove --force "$$dir"; done; true
	git worktree prune

clean:
	swift package clean
	rm -rf .build
	git worktree prune
