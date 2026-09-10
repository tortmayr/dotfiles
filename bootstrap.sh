#!/usr/bin/env bash
set -euo pipefail

# Bootstrap the portable dotfiles: command shims and zsh plugins.
#
# Deliberately does not link the zsh/ package into $HOME. How that tree lands
# is the caller's decision: `stow` on a workstation, a plain copy inside a
# container image. Idempotent — safe to re-run.
#
# Usage: bootstrap.sh [-f|--force]
#   -f/--force: re-install plugins that are already present

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=true ;;
    -h|--help)  sed -n '3,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

info() { printf '\033[34m[info]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[32m[ok]\033[0m    %s\n' "$*"; }

# Debian and Ubuntu ship `fd` and `bat` under names that avoid clashing with
# other packages. The config uses the upstream names throughout, including
# from `sh -c` contexts such as $MANPAGER where a shell alias would not exist,
# so link the short name into ~/.local/bin when only the Debian one is there.
link_shim() {
  local short="$1" packaged="$2" target

  if command -v "$short" >/dev/null 2>&1; then
    ok "$short already resolves"
    return 0
  fi
  if ! target="$(command -v "$packaged" 2>/dev/null)"; then
    info "neither $short nor $packaged found — skipping shim"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$target" "$HOME/.local/bin/$short"
  ok "$short -> $target"
}

info "=== Command shims ==="
link_shim fd fdfind
link_shim bat batcat

info "=== Zsh plugins ==="
if [[ "$FORCE" == true ]]; then
  "$SCRIPT_DIR/install-plugins.sh" --force
else
  "$SCRIPT_DIR/install-plugins.sh"
fi

ok "Bootstrap complete"
