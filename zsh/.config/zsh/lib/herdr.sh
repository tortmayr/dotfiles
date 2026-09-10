#!/usr/bin/env bash
#
# herdr.sh — reusable shell helpers for scripting herdr (workspaces, panes,
# agents) from automation. Composable building blocks: each function does one
# thing, prints the durable id it produced on stdout, logs to stderr, and uses
# distinct exit codes — so callers can chain them cleanly:
#
#   source "$SCRIPT_LIBRARY_DIR/herdr.sh"
#   ws=$(herdrWs ~/Git/Personal/dev-xp) || exit 1
#   herdr workspace focus "$ws"          # focus is the caller's choice, not ours
#
# These talk to the running herdr server over its unix socket. The library
# assumes it is run from inside a herdr session (a server is already up); it
# does not start one. Commands fail with their own errors if no server is
# reachable.
#
# Public API:
#   herdrWs <dir> [--no-reuse]   ensure a workspace for <dir> exists; print its id
#   herdrRun [-v|-h] [--workspace W] [--window T] [--no-focus] [cmd…]
#                                open a new pane (new tab by default, or a split)
#                                and optionally run a command; print the pane id
#
# Internals are prefixed `_herdr_`; do not rely on them from outside this file.
#
# Requires: herdr, jq. git is used when present (to anchor on the repo root).


# =============================================================================
# PUBLIC API
# =============================================================================

# Ensure a herdr workspace exists for <dir> and print its workspace id.
#
# Name resolution:
#   * <dir> must be an existing directory (else exit 2).
#   * If <dir> is inside a git repo, we anchor on the repo root: its basename is
#     the workspace name and the root is the first pane's cwd.
#   * Otherwise we use <dir> itself: its basename is the name, <dir> the cwd.
#
# By default an existing workspace whose label matches the name is reused (first
# match wins, exact, case-sensitive). --no-reuse always creates a fresh one.
# Workspaces we create are labelled explicitly so the name stays stable even if
# the first pane's directory later changes.
#
# Has no interactive side effects: it never focuses anything.
#
# stdout: workspace id (e.g. "w14"). stderr: human-facing logs.
# exit:   0 ok · 1 operational failure · 2 usage error.
#
#   herdrWs <dir> [--no-reuse]
herdrWs() {
  local dir="" reuse=1 arg
  for arg in "$@"; do
    case "$arg" in
      --no-reuse) reuse=0 ;;
      -*) _herdr_log "herdrWs: unknown option: $arg"; return 2 ;;
      *)
        if [ -z "$dir" ]; then dir="$arg"
        else _herdr_log "herdrWs: unexpected extra argument: $arg"; return 2; fi
        ;;
    esac
  done
  [ -n "$dir" ] || { _herdr_log "herdrWs: usage: herdrWs <dir> [--no-reuse]"; return 2; }
  [ -d "$dir" ] || { _herdr_log "herdrWs: not a directory: $dir"; return 2; }

  command -v herdr >/dev/null 2>&1 || { _herdr_log "herdrWs: herdr not found in PATH"; return 1; }
  command -v jq >/dev/null 2>&1 || { _herdr_log "herdrWs: jq is required"; return 1; }

  # Resolve name + cwd: prefer the git repo root, else the literal directory.
  local cwd name root
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$root" ]; then
    cwd="$root"
  else
    cwd=$(cd "$dir" && pwd -P) || { _herdr_log "herdrWs: cannot resolve: $dir"; return 1; }
  fi
  name=$(basename -- "$cwd")

  # Reuse an existing workspace with this label unless told not to.
  if [ "$reuse" -eq 1 ]; then
    local existing; existing=$(_herdr_find_workspace_by_label "$name") || return 1
    if [ -n "$existing" ]; then
      _herdr_log "herdrWs: reusing workspace '$name' ($existing)"
      printf '%s\n' "$existing"
      return 0
    fi
  fi

  # Create a fresh workspace, labelled explicitly and without stealing focus.
  local out ws
  out=$(herdr workspace create --cwd "$cwd" --label "$name" --no-focus 2>/dev/null) \
    || { _herdr_log "herdrWs: workspace create failed for '$name'"; return 1; }
  ws=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
  [ -n "$ws" ] || { _herdr_log "herdrWs: could not read new workspace id"; return 1; }

  _herdr_log "herdrWs: created workspace '$name' ($ws) at $cwd"
  printf '%s\n' "$ws"
}

# Open a new pane and optionally run a command in it; print the new pane id.
#
# Placement:
#   * Default: a new tab (window) in the current workspace.
#   * With -v / -h, or when --window is given: split an existing pane instead.
#       -v -> split downward, -h -> split rightward. --window without -v/-h
#       defaults to a rightward split.
#
# Targeting (defaults to the current workspace/pane):
#   --workspace W  act in workspace W (new tab created there, or its active
#                  tab's pane is split).
#   --window T     split the active pane of tab T (implies a split). The
#                  workspace is taken from the tab id (the "wN" prefix).
#
# Everything after the options is the command; if omitted, the pane is opened
# with a plain shell. The new pane is focused unless --no-focus is given.
#
# stdout: new pane id (e.g. "w1:p3"). stderr: human-facing logs.
# exit:   0 ok · 1 operational failure · 2 usage error.
#
#   herdrRun [-v|-h] [--workspace W] [--window T] [--no-focus] [cmd…]
herdrRun() {
  command -v herdr >/dev/null 2>&1 || { _herdr_log "herdrRun: herdr not found in PATH"; return 1; }
  command -v jq >/dev/null 2>&1 || { _herdr_log "herdrRun: jq is required"; return 1; }

  local split=0 direction="" ws="" tab="" focus=1
  local -a rest=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -v) split=1; direction=down ;;
      -h) split=1; direction=right ;;
      --workspace) ws="$2"; shift ;;
      --workspace=*) ws="${1#*=}" ;;
      --window) tab="$2"; split=1; shift ;;
      --window=*) tab="${1#*=}"; split=1 ;;
      --no-focus) focus=0 ;;
      --) shift; rest+=("$@"); break ;;
      -*) _herdr_log "herdrRun: unknown option: $1"; return 2 ;;
      *) rest+=("$@"); break ;;   # first non-option begins the command
    esac
    shift
  done
  [ "$split" -eq 1 ] && [ -z "$direction" ] && direction=right
  local focusflag=--focus; [ "$focus" -eq 0 ] && focusflag=--no-focus
  local cmd="${rest[*]}"

  local out pane
  if [ "$split" -eq 0 ]; then
    # New tab (window) in the target workspace; run in its root pane.
    local -a args=(tab create)
    [ -n "$ws" ] && args+=(--workspace "$ws")
    args+=("$focusflag")
    out=$(herdr "${args[@]}" 2>/dev/null) \
      || { _herdr_log "herdrRun: tab create failed"; return 1; }
    pane=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
  else
    # Split an existing pane. Resolve which one from --window / --workspace,
    # else let herdr use the currently focused pane.
    local target=""
    if [ -n "$tab" ]; then
      target=$(_herdr_active_pane_in_tab "$tab") \
        || { _herdr_log "herdrRun: no pane found in window $tab"; return 1; }
    elif [ -n "$ws" ]; then
      local atab; atab=$(_herdr_ws_active_tab "$ws") \
        || { _herdr_log "herdrRun: workspace $ws not found"; return 1; }
      target=$(_herdr_active_pane_in_tab "$atab") \
        || { _herdr_log "herdrRun: no pane found in workspace $ws"; return 1; }
    fi
    local -a args=(pane split)
    if [ -n "$target" ]; then args+=("$target"); else args+=(--current); fi
    args+=(--direction "$direction" "$focusflag")
    out=$(herdr "${args[@]}" 2>/dev/null) \
      || { _herdr_log "herdrRun: pane split failed"; return 1; }
    pane=$(printf '%s' "$out" | jq -r '.result.pane.pane_id // empty')
  fi
  [ -n "$pane" ] || { _herdr_log "herdrRun: could not read new pane id"; return 1; }

  if [ -n "$cmd" ]; then
    herdr pane run "$pane" "$cmd" \
      || { _herdr_log "herdrRun: created pane $pane but command failed to start"; return 1; }
  fi
  printf '%s\n' "$pane"
}


# =============================================================================
# INTERNAL HELPERS — prefixed `_herdr_`; subject to change without notice.
# =============================================================================

_herdr_log() { printf 'herdr.sh: %s\n' "$*" >&2; }

# Print the active_tab_id of workspace $1, or nothing. Returns 1 on API failure.
_herdr_ws_active_tab() {
  herdr workspace list 2>/dev/null \
    | jq -r --arg ws "$1" 'first(.result.workspaces[] | select(.workspace_id == $ws) | .active_tab_id) // empty'
}

# Print a pane id to split for tab $1: the focused pane in that tab, else the
# first one. The workspace is the tab id's "wN" prefix. Empty if the tab has none.
_herdr_active_pane_in_tab() {
  local tab="$1" ws="${1%%:*}"
  herdr pane list --workspace "$ws" 2>/dev/null \
    | jq -r --arg t "$tab" '
        [.result.panes[]? | select(.tab_id == $t)] as $p
        | ((first($p[] | select(.focused)) | .pane_id) // ($p[0].pane_id) // empty)'
}

# Print the workspace id of the first workspace whose label exactly matches $1,
# or nothing if there is no match. Returns 1 only if the API call itself fails.
_herdr_find_workspace_by_label() {
  local name="$1" out
  out=$(herdr workspace list 2>/dev/null) \
    || { _herdr_log "could not list workspaces"; return 1; }
  printf '%s' "$out" \
    | jq -r --arg name "$name" \
        'first(.result.workspaces[] | select(.label == $name) | .workspace_id) // empty'
}


# --- run-vs-source guard -----------------------------------------------------
# If executed instead of sourced, print usage.
if ! (return 0 2>/dev/null); then
  sed -n '3,26p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'
  exit 0
fi
