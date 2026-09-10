#!/usr/bin/env sh
# Portable environment. Anything that names a specific machine, package
# manager, GUI application or client belongs in host.d/ instead.

export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Shell libraries shipped alongside these dotfiles (worktree.sh, git.sh).
export SCRIPT_LIBRARY_DIR="$ZDOTDIR/lib"

# Root that `sgit` / `cgit` scan for git repositories. Overridden in host.d
# where repositories do not live under $HOME (an enclave container mirrors the
# host's absolute paths, so $HOME/Git is empty there).
export USER_GIT_DIR="${USER_GIT_DIR:-$HOME/Git}"

# EDITOR is deliberately not set here: it is `code` on a workstation and a
# terminal editor everywhere else. Every host.d layer must set it.

# Path additions. Listing a directory that does not exist is harmless.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Github Dark Dimmed Colors for fzf
 export FZF_DEFAULT_OPTS="
  --color=fg:#adbac7,bg:#1c2128,hl:#539bf5
  --color=fg+:#cdd9e5,bg+:#22272e,hl+:#6cb6ff
  --color=info:#c69026,prompt:#f47067,pointer:#57ab5a
  --color=marker:#b083f0,spinner:#76e3ea,header:#768390
  --color=border:#373e47,label:#909dab,query:#adbac7
  --color=gutter:#1c2128
  --color=selected-bg:#22272e
  --color=selected-fg:#cdd9e5
  --border='rounded'"


# `fd` and `bat` are the upstream names. Debian ships them as `fdfind` and
# `batcat`; bootstrap.sh links the short names into ~/.local/bin so this
# config reads the same on every distribution.
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix'
# fzf overrides
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'if [ -d {} ]; then eza -ah -1 --color=always --icons {}; else bat -n --color=always --style=numbers {} 2>/dev/null || file -b {}; fi'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
# Configure man to use bat
export MANPAGER="sh -c 'awk '\''{ gsub(/\x1B\[[0-9;]*m/, \"\", \$0); gsub(/.\x08/, \"\", \$0); print }'\'' | bat -p -lman'"
