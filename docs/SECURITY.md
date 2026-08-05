# Security

How this project handles secrets, permissions, and other sensitive material.

## Secrets & credentials

focusd has **no secrets**. It stores nothing, reads no credentials, opens no network connections, and takes no input beyond a single global key chord. There is no secret manager, no token, no config file with sensitive material.

## Permissions & privacy posture

The relevant "security" surface for a hotkey daemon is the macOS **privacy/permission** model, and focusd is deliberately minimal there:

- **No Accessibility / Input-Monitoring grant.** focusd registers one chord with the WindowServer via Carbon `RegisterEventHotKey` and never observes the keyboard stream, so it needs no TCC permission. A `CGEventTap` would have required one — this is a conscious choice ([ADR 0002](architecture/decisions/0002-carbon-hotkey-over-cgeventtap.md)).
- **No elevated privileges.** It runs as a per-user **LaunchAgent** in the GUI session, never as root or a system LaunchDaemon.
- **App activation only.** Its only side effect on the system is bringing an installed app to the foreground via `NSWorkspace` — an unprivileged operation.

## Rules

- **Never commit secrets.** (There are none today; keep it that way — no keys in code or committed config.)
- **Local settings are git-ignored.** `.claude/settings.local.json` and any local env files are never committed (see `.gitignore`).
- **Keep the permission footprint at zero.** If a future change reaches for a `CGEventTap` or any capability needing a TCC grant, record the trade-off in a new ADR first.

## Reporting

This is a personal project. Report anything security-relevant by opening an issue at <https://github.com/dsaenztagarro/focusd/issues>.
