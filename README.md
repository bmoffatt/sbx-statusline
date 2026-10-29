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
