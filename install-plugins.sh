#!/usr/bin/env bash
set -euo pipefail

# Plugin installer
# Clones plugins listed in plugins.list at their pinned versions.
#
# Usage: install-plugins.sh [-f|--force]
#   No flags:    skip plugins whose target directory already exists
#   -f/--force:  remove existing plugin directory before cloning (re-install)

ZSH_PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins"
TMUX_PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_LIST="$SCRIPT_DIR/plugins.list"

FORCE=false

# ---------- helpers -----------------------------------------------------------

info()  { printf '\033[34m[info]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[32m[ok]\033[0m    %s\n' "$*"; }
err()   { printf '\033[31m[err]\033[0m   %s\n' "$*" >&2; }

# ---------- flag parsing ------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=true ;;
    -h|--help)
      sed -n '3,10p' "$0"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# ---------- functions ---------------------------------------------------------

plugin_dir() {
  local repo="$1"
  case "$repo" in
    catppuccin/tmux) echo "$TMUX_PLUGIN_DIR/catppuccin/tmux" ;;
    *)               echo "$ZSH_PLUGIN_DIR/${repo#*/}" ;;
  esac
}

install_plugin() {
  local repo="$1"
  local version="$2"
  local dest
  dest="$(plugin_dir "$repo")"

  if [[ -d "$dest" ]]; then
    if [[ "$FORCE" == false ]]; then
      ok "$repo already installed — skipping (use -f to reinstall)"
      return
    fi
    warn "Removing existing $dest"
    rm -rf "$dest"
  fi

  mkdir -p "$(dirname "$dest")"

  # SHA detection: 40 hex characters means a commit hash, not a tag/branch.
  if [[ "$version" =~ ^[0-9a-f]{40}$ ]]; then
    info "Cloning $repo (commit $version)..."
    git clone --depth 1 "https://github.com/$repo.git" "$dest"
    git -C "$dest" fetch --depth 1 origin "$version"
    git -C "$dest" checkout "$version"
  else
    info "Cloning $repo @ $version..."
    git clone --depth 1 --branch "$version" "https://github.com/$repo.git" "$dest"
  fi

  ok "$repo installed"
}

# ---------- main --------------------------------------------------------------

main() {
  if [[ ! -f "$PLUGIN_LIST" ]]; then
    err "Plugin list not found: $PLUGIN_LIST"
    exit 1
  fi

  echo ""
  info "Installing plugins from $PLUGIN_LIST"
  echo ""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blank lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse: org/repo  version
    read -r repo version <<< "$line"

    if [[ -z "$repo" || -z "$version" ]]; then
      warn "Skipping malformed line: $line"
      continue
    fi

    install_plugin "$repo" "$version"
  done < "$PLUGIN_LIST"

  echo ""
  ok "All plugins processed"
}

main
