# dotfiles

Portable configuration. Everything here is expected to work unchanged on a
Linux workstation, a macOS machine and inside a container — nothing in this
repository may name a specific host, user, client or credential.

Configs are installed whether or not the corresponding application is present;
an unused config file costs nothing, and it means a fresh machine is one
command away from being usable.

Machine-specific configuration layers on top; see [Layering](#layering).

## Install

```bash
git clone https://github.com/tortmayr/dotfiles.git
cd dotfiles
./install.sh                          # workstation profile, via GNU Stow
./bootstrap.sh                        # fd/bat shims + pinned zsh plugins
```

```bash
./install.sh --profile container      # smaller set, no desktop
./install.sh --method copy            # for images with no stow
./install.sh --dry-run                # show what would happen
./install.sh zsh tmux                 # explicit packages, ignore profiles
```

## Profiles

A profile is a plain list of package names in `profiles/`. Keeping the package
set next to the packages means adding a package reaches every consumer,
instead of every consumer holding its own copy of the list.

| Profile | Contents |
|---|---|
| `workstation` | everything |
| `container` | `bash bat bin git lazygit tmux zsh` — no desktop, no agent configs |
| `minimal` | `bat git zsh` |

## Packages

| Package | Installs |
|---|---|
| `ai-review` `diff-review` | review tool settings |
| `bash` | `~/.bashrc` |
| `bat` | bat config + GitHub Dark Dimmed theme |
| `bin` | `~/.local/bin`: `nr`, `kp`, `tmux-manager`, `script-manager`, `herdr-cp` |
| `claude` `codex` `pi` | agent CLI settings |
| `code` | VS Code user settings and keybindings |
| `enclave` | enclave config and host commands |
| `git` | `~/.gitconfig`, `~/.config/git/ignore` |
| `herdr` | herdr terminal multiplexer config |
| `kitty` | kitty terminal config |
| `lazygit` | lazygit config |
| `profile` | `~/.profile` |
| `tmux` | `~/.tmux.conf` |
| `zsh` | `.zshenv`, `.zshrc`, p10k, `lib/` (incl. `worktree.sh`, `git.sh`, `herdr.sh`) |

## Layering

Three layers, lowest precedence first:

| Layer | Tracked | Purpose |
|---|---|---|
| this repository | yes, publicly | Portable defaults |
| `~/.config/zsh/host.d/*.zsh` | yes, privately | Per-machine: desktop tools, package managers, work paths, `EDITOR` |
| `~/.config/zsh/local.d/*.zsh` | no | Machine-local: secrets, client-specific paths |

`.zshenv` additionally sources `host.d/*.zshenv` for anything that must be set
before `.zshrc` — a `brew shellenv` that puts tools on `PATH`, for example.

Both directories are globbed with zsh's `(N)` qualifier, so a missing one is a
no-op rather than an error. That is what lets this repository be checked out on
its own, with no overlay at all.

Two packages use their application's own include mechanism rather than a `.d`
directory:

- `git` — `.gitconfig` ends with `[include] path = ~/.config/git/local.gitconfig`,
  which supplies identity (name, email, signing key) and any local override.
- `profile` — `.profile` ends with `. ~/.profile.local` when that file exists.

`EDITOR` and `USER_GIT_DIR` are intentionally **not** set here: every host
layer must set both. Defaulting them in the portable layer would run before
`host.d` and leave an overlay's own `${VAR:-...}` unable to take effect.

`install.sh` passes `--no-folding` to stow, so a private overlay package can
populate the same directory as a public one.

## Command names

The config calls `fd` and `bat`. Debian and Ubuntu ship those binaries as
`fdfind` and `batcat`; `bootstrap.sh` links the short names into
`~/.local/bin`. A shell alias would not be enough — `$MANPAGER` invokes `bat`
through `sh -c`.

## Known consumers

- [`tortmayr/dev-xp`](https://github.com/tortmayr/dev-xp) — workstation
  overlay, adds this repository as a submodule at `core/`.
- [`tortmayr/enclave-extensions`](https://github.com/tortmayr/enclave-extensions)
  — the `shell-ext` enclave feature, which installs the `container` profile
  into an agent container image and ships its own `host.d` layer.
