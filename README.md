## sbx Claude sandbox kit

[`bmoffatt/sbx-statusline`](https://github.com/bmoffatt/sbx-statusline) is an sbx mixin kit that adds my Claude
statusline and rules to a sandbox.

One-time setup: sbx only installs kits from allowlisted sources, and the default is `docker.io/`. Add my GitHub
account (this replaces the list, so keep `docker.io/`):

``` sh
sbx settings set kit.allowedSources '["docker.io/","github.com/bmoffatt/"]'
```

Create a sandbox with the kit, from the project directory:

``` sh
sbx run claude --kit 'git+https://github.com/bmoffatt/sbx-statusline' --name my-project
```

Later attaches are just `sbx run my-project`. `--kit` applies only when the sandbox is created, so an existing sandbox
must be removed (`sbx rm`) and recreated to pick it up.
