#!/usr/bin/env bash
set -euo pipefail

# Link (or copy) dotfile packages into a target home directory.
#
# Packages are GNU Stow packages: each top-level directory mirrors the paths it
# owns below $HOME. Which ones to install is named by a profile in profiles/,
# so the package set lives next to the packages instead of in whatever
# repository happens to be consuming them.
#
# Usage: install.sh [options] [package...]
#   -p, --profile NAME   profile from profiles/ (default: workstation)
#   -t, --target DIR     install into DIR (default: $HOME)
#   -m, --method MODE    stow (default) or copy, for hosts without GNU Stow
#   -n, --dry-run        report what would happen, change nothing
#   -h, --help           this text
#
# Explicit package arguments override --profile.
#
# Command shims and zsh plugins are a separate step: see bootstrap.sh.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE="workstation"
TARGET="$HOME"
METHOD="stow"
DRY_RUN=false
PACKAGES=()

info() { printf '\033[34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[32m[ok]\033[0m    %s\n' "$*"; }
err()  { printf '\033[31m[err]\033[0m   %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--profile) PROFILE="${2:?--profile needs a name}"; shift ;;
    -t|--target)  TARGET="${2:?--target needs a directory}"; shift ;;
    -m|--method)  METHOD="${2:?--method needs stow or copy}"; shift ;;
    -n|--dry-run) DRY_RUN=true ;;
    -h|--help)    sed -n '5,21p' "$0"; exit 0 ;;
    -*)           err "Unknown option: $1"; exit 1 ;;
    *)            PACKAGES+=("$1") ;;
  esac
  shift
done

case "$METHOD" in
  stow|copy) ;;
  *) err "--method must be stow or copy, got: $METHOD"; exit 1 ;;
esac

# Resolve the package list: explicit arguments win over the profile.
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  profile_file="$REPO_DIR/profiles/$PROFILE"
  if [[ ! -f "$profile_file" ]]; then
    err "No such profile: $PROFILE"
    err "Available: $(cd "$REPO_DIR/profiles" && echo *)"
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && PACKAGES+=("$line")
  done < "$profile_file"
  info "Profile '$PROFILE': ${PACKAGES[*]}"
fi

for pkg in "${PACKAGES[@]}"; do
  if [[ ! -d "$REPO_DIR/$pkg" ]]; then
    err "No such package: $pkg"
    exit 1
  fi
done

if [[ "$METHOD" == "stow" ]] && ! command -v stow >/dev/null 2>&1; then
  err "GNU Stow is not installed; re-run with --method copy"
  exit 1
fi

mkdir -p "$TARGET"

if [[ "$METHOD" == "stow" ]]; then
  # --no-folding keeps real directories and links individual files, so a
  # second package (a host-specific overlay) can populate the same directory.
  args=(-d "$REPO_DIR" -t "$TARGET" --no-folding -S)
  $DRY_RUN && args=(-n -v "${args[@]}")
  stow "${args[@]}" "${PACKAGES[@]}"
else
  # Plain copy for images that have no stow: same result, no symlinks back
  # into a checkout that will not exist at runtime.
  for pkg in "${PACKAGES[@]}"; do
    if $DRY_RUN; then
      info "would copy $pkg/ -> $TARGET/"
    else
      cp -a "$REPO_DIR/$pkg/." "$TARGET/"
    fi
  done
fi

$DRY_RUN && { ok "Dry run complete"; exit 0; }
ok "Installed ${#PACKAGES[@]} package(s) into $TARGET"
