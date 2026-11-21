# Windows DevSpace in MSYS64

The Windows service root is `C:\msys64\home\lynn` (MSYS `/home/lynn`).
`win-git/server_devspace.sh` is the shared service manager. Do not launch a second
copy from the old Windows user profile.

| Component | Location |
| --- | --- |
| DevSpace CLI and matching native Node | `.local/devspace/` |
| DevSpace configuration and logs | `.devspace/` |
| SQLite/OAuth/workspace state | `.local/share/devspace/` |
| cloudflared executable | `.local/bin/cloudflared.exe` |
| Tunnel config and credentials | `.cloudflared/` |
| Allowed projects | `newhome/`, `sh/` |

DevSpace listens on loopback port 7676; the named tunnel publishes
`https://win.sherylynn.win/mcp`. Configuration and secrets remain local and are
not committed to this repository. `USERPROFILE` is not changed globally.

The `DevSpace-Windows` and `DevSpace-Cloudflare` scheduled tasks run as the normal
Windows user at login, keep the foreground commands alive and retry failures.
They have no execution time limit and can run on battery. Register them using
`bash ~/sh/win-git/devspace.sh enable-autostart` from MSYS2.

Use `bash ~/sh/win-git/server_devspace.sh status` for HTTP and tunnel readiness,
or `states` for machine-readable status. `start` is idempotent; `stop`,
`restart-devspace`, and `restart-cloudflared` handle native Windows process IDs.

The public tool surface stays in Codex mode: `open_workspace`, `read`,
`apply_patch`, `exec_command`, `write_stdin`, and `show_changes`.
`DEVSPACE_BASH_PATH` explicitly selects MSYS2 Bash for command execution.
The CLI's bundled Node takes precedence in PATH because `better-sqlite3` must
match its ABI. Git for Windows is preferred for native Node operations: MSYS
Git reports `/home/...` repository roots, which native Node cannot use as cwd.
Git remains a Windows platform dependency; its installation is not relocated.

## Verification on 2026-11-21

- DevSpace `1.1.0-beta.4` with Node `v24.22.1`, ABI 137; in-memory SQLite open/query passed.
- Both scheduled tasks running from MSYS64 paths; cloudflared ready with four edge connections over HTTP/2.
- Local and public unauthenticated `/mcp` returned 401 as expected.
- Authenticated public OAuth/MCP calls opened both allowed repositories with Git review available.
- MCP `exec_command` used Bash 5.2 with HOME `/home/lynn`; Node and Git commands ran successfully.
- MCP `write_stdin` returned command output; `apply_patch` created/deleted a temporary sentinel and `show_changes` reported it.
- Public checks from this machine use the existing proxy `127.0.0.1:10808` where direct connectivity is unavailable.
- No Windows reboot or logout/login was performed; login triggers were inspected rather than exercised by reboot.
