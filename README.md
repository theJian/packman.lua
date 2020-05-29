# packman


## Getting Started

#### Prerequisites

- Neovim(>= 4.0)
- Git

#### Installing

The whole plugin is just a lua file.
Run this command to install or update packman.
```sh
$ curl https://raw.githubusercontent.com/theJian/packman.lua/master/packman.lua -o $HOME/.config/nvim/lua/packman.lua
```

Configure packman by adding just one single line to your `init.vim`
```VimL
lua require 'packman'
```

That's it! Unlike other plugin managers, which are typically reading plugin list from `init.vim`, packman takes a different approach. Keep reading!

#### Adding/Removing plugins

Packman exposes several methods that you can use to add or remove plugins. To access them you can use `:lua` command.

For example, this command will install a plugin from a git remote url. **Don't forget the surrounding quotes!**
```
:lua packman.get "plugin_git_remote_url"
```

If plugin is hosted on github, you can simply use `username/plugin`

```
:lua packman.get "username/plugin"
```

To remove a installed plugin, pass the exact plugin name to `packman.remove`.

```
:lua packman.remove "plugin"
```

#### Updating plugin

```
:lua packman.update "plugin"
```

#### Synchronizing plugin list

Since plugin list isn't part of the `init.vim` file, we can't keep plugins in sync by syncing the configuration. Pacman reads plugin list from a individual file and can generate this file from installed plugins.

```
:lua packman.dump()
```

By default a file `packfile` will be generated at the same directory with where packman file is located in. If you follow the installation instruction then it can be found under `$HOME/.config/nvim/lua`.

Then you can sync `packfile` and install plugins from it. It reads from the same filename as the output file of dump method.
```
:lua packman.install()
```
