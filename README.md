## sbx Claude sandbox kit

[`bmoffatt/sbx-statusline`](https://github.com/bmoffatt/sbx-statusline) is an sbx mixin kit that adds my Claude
statusline and rules to a sandbox.

Create a sandbox with the kit, from the project directory:

``` sh
sbx run claude --kit docker.io/bmoffatt/sbx-statusline:latest --name my-project
```

`docker.io/` is on sbx's default kit allowlist, so no setup is needed. Every push to `main` republishes `:latest` to
[Docker Hub](https://hub.docker.com/r/bmoffatt/sbx-statusline) (see `.github/workflows/publish.yml`).

Later attaches are just `sbx run my-project`. `--kit` applies only when the sandbox is created, so an existing sandbox
must be removed (`sbx rm`) and recreated to pick it up.

### From git instead

sbx only installs kits from allowlisted sources. Add my GitHub account first (this replaces the list, so keep
`docker.io/`):

``` sh
sbx settings set kit.allowedSources '["docker.io/","github.com/bmoffatt/"]'
sbx run claude --kit 'git+https://github.com/bmoffatt/sbx-statusline' --name my-project
```
