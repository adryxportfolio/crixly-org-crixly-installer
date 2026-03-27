# Crixly (white-labeled OpenClaw)

Goal: ship a Crixly-branded distribution of OpenClaw with an enforced online license gate.

## Non-negotiables
- No user-facing "OpenClaw" anywhere.
- Allowed: subtle footer text "Powered by OpenClaw" at bottom of web UI.
- License: online activation/validation, block startup if unlicensed.
- Platforms: Windows, macOS, Linux.
- Skills/plugins bundled and preinstalled.

## Approach (high level)
1) `crixly-cli` wrapper (Node) provides `crixly` command.
2) `crixly` runs license check against Supabase then launches underlying OpenClaw runtime.
3) Branding overrides applied via config + patching UI assets (title/favicon) and CLI surface commands.

## Next
- Define Supabase tables + RPC contract for license validation.
- Implement `crixly-cli` with subcommands mirroring key OpenClaw commands (onboard/doctor/configure/status/gateway).
- Package per-OS installers (Win EXE + one-liner; macOS pkg/brew cask; Linux curl|bash + systemd).
