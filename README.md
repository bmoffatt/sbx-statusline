## sbx-statusline

[`bmoffatt/sbx-statusline`](https://github.com/bmoffatt/sbx-statusline) is my Claude Code statusline: directory, git
branch, model, context window, cost, and 5h/7d rate-limit gauges. It ships two ways, both using the same script:

- [Claude Code plugin](#claude-code-plugin-host) for Claude Code running directly on your machine
- [sbx kit](#sbx-claude-sandbox-kit) for Docker sandboxes

A leading icon shows where Claude is running: apple on the macOS host, whale plus the sandbox name inside a sandbox,
penguin on other Linux.

### Claude Code plugin (host)

Requirements: `jq`, and a [Nerd Font](https://www.nerdfonts.com/) in your terminal for the icons.

``` text
/plugin install sbx-statusline --marketplace bmoffatt/sbx-statusline
```

That is the whole setup. A plugin can't set `statusLine` itself, so the plugin ships a `SessionStart` hook
(`scripts/sync.sh`) that runs every session and:

- copies `files/home/.claude/statusline.sh` to `~/.claude/statusline.sh` (so plugin updates reach you)
- merges `statusLine` and `preferredNotifChannel` into `~/.claude/settings.json`, leaving your other keys alone

It overwrites those two settings and the script on every session, so local edits to either are reverted. Start a new
session after installing to see the line. To remove it, uninstall the plugin and delete the `statusLine` key from
`~/.claude/settings.json`.

### sbx Claude sandbox kit

The sbx mixin kit adds the same statusline to a sandbox.

Create a sandbox with the kit, from the project directory:

``` sh
sbx run claude --kit docker.io/bmoffatt/sbx-statusline:latest --name my-project
```

`docker.io/` is on sbx's default kit allowlist, so no setup is needed. Every push to `main` republishes `:latest` to
[Docker Hub](https://hub.docker.com/r/bmoffatt/sbx-statusline) (see `.github/workflows/publish.yml`).

Later attaches are just `sbx run my-project`. `--kit` applies only when the sandbox is created, so an existing sandbox
must be removed (`sbx rm`) and recreated to pick it up.

#### From git instead

sbx only installs kits from allowlisted sources. Add my GitHub account first (this replaces the list, so keep
`docker.io/`):

``` sh
sbx settings set kit.allowedSources '["docker.io/","github.com/bmoffatt/"]'
sbx run claude --kit 'git+https://github.com/bmoffatt/sbx-statusline' --name my-project
```

### Terminal bell marker for tmux

With several Claude panes open in tmux, a plain terminal bell can't tell you which pane rang: tmux's `alert-bell` only
reports a window's active pane. This adds a Claude Code `Notification` hook (`files/home/.claude/claude-bell.sh`) that
sets the pane's title to `🔔 claude` by writing an OSC 2 sequence straight to the pane's pty. A tmux
`pane-title-changed` hook latches that into a per-pane `@bell` option, and `pane-border-format` shows a red label on
that pane until you select it.

It works in both setups:

- **Host plugin:** `hooks/hooks.json` registers the script as a `Notification` hook, run from the plugin directory.
  `scripts/sync.sh` and `settings.json` are not involved.
- **sbx kit:** the script is copied to `~/.claude/claude-bell.sh` with the statusline, and the startup command appends it
  to `hooks.Notification` in the sandbox's `settings.json`. Other hooks already there are kept, and restarts don't add
  duplicates.

Hooks have no controlling tty and their stdout is captured, so the script walks up the process tree to find Claude's
pty. It falls back to `/proc/<pid>/fd/0` where `ps` has no `-o tty=` (busybox). `preferredNotifChannel` stays
`terminal_bell`, so the literal bell still rings too.

The tmux side is not installed by this repo. Add this to your own `tmux.conf` (tested on tmux 3.8, `focus-events` is not
required):

``` tmux
set -g monitor-bell on
set -g bell-action other
set -g pane-border-status top
set -g pane-border-format '#{?@bell,#[bg=red#,fg=white#,bold] 🔔 #{pane_index}: #{pane_title} #[default],#{pane_index}: #{pane_title}}'
set-hook -g pane-title-changed 'if -F "#{m:*🔔*,#{pane_title}}" "run-shell \"tmux set -p -t #{pane_id} @bell 1\""'
set-hook -g after-select-pane 'set -p -u @bell'
set-hook -g after-select-window 'set -p -u @bell'
set-hook -g pane-focus-in 'set -p -u @bell'
```

`pane-border-status top` turns on a one-line border label for every pane in every window, so it changes your layout
even when no bell is showing.
