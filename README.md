# dotfiles

Portable shell configuration. Everything here is expected to work unchanged on
a Linux workstation, a macOS machine and inside a container — nothing in this
repository may name a specific host, user, client or credential.

Machine-specific configuration layers on top; see [Layers](#layers).

## Layout

```text
zsh/                              # stow package, links into $HOME
  .zshenv                         # XDG dirs, ZDOTDIR, host.d/*.zshenv
  .config/zsh/
    .zshrc                        # options, history, keybindings, layer loading
    .p10k.zsh                     # powerlevel10k prompt
    lib/{exports,aliases,functions,setup}.zsh
    lib/{worktree.sh,git.sh}      # also sourceable from bash scripts
plugins.list                      # pinned zsh/tmux plugin versions
install-plugins.sh                # clones plugins.list into ~/.config/zsh/plugins
bootstrap.sh                      # command shims + install-plugins.sh
```

## Install

```bash
git clone https://github.com/tortmayr/dotfiles.git
cd dotfiles
stow -t ~ zsh --no-folding
./bootstrap.sh
```

`bootstrap.sh` links `fd` and `bat` into `~/.local/bin` when the system only
provides Debian's `fdfind` / `batcat`, then clones the pinned plugins. The
config always uses the upstream names, including from `sh -c` contexts such as
`$MANPAGER` where a shell alias would not apply.

## Layers

`.zshrc` sources two optional directories, in order, after the portable config:

| Directory | Tracked | Purpose |
|---|---|---|
| `~/.config/zsh/host.d/*.zsh` | yes, elsewhere | Per-machine: desktop tools, package managers, work paths, `EDITOR` |
| `~/.config/zsh/local.d/*.zsh` | no | Machine-local: secrets, client-specific paths |

`.zshenv` additionally sources `host.d/*.zshenv` for anything that must be set
before `.zshrc` — a `brew shellenv` that puts tools on `PATH`, for example.

Both are globbed with zsh's `(N)` qualifier, so a missing directory is a no-op
rather than an error. That is what lets this repository be checked out on its
own, with no overlay at all.

`EDITOR` is intentionally **not** set here: every `host.d` layer must set it.

Known consumers of these layers:

- [`tortmayr/dev-xp`](https://github.com/tortmayr/dev-xp) — workstation
  overlay, adds this repository as a submodule at `dotfiles/core`.
- [`tortmayr/enclave-extensions`](https://github.com/tortmayr/enclave-extensions)
  — the `shell-ext` enclave feature, which installs this repository into an
  agent container image and ships its own `host.d` layer.
