# Git worktree utilities
# Sourceable by both zsh and bash — no zsh-specific syntax.

__wt_err() {
  echo "wt: $*" >&2
}

__wt_repo_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    __wt_err "not in a git repository"
    return 1
  }
  echo "$root"
}

__wt_default_remote() {
  local remote
  remote=$(git remote | head -1) || {
    __wt_err "no remotes configured"
    return 1
  }
  if [[ -z "$remote" ]]; then
    __wt_err "no remotes configured"
    return 1
  fi
  echo "$remote"
}

__wt_default_branch() {
  local remote="$1"
  local ref branch

  # Try local cache first (fast, no network)
  ref=$(git symbolic-ref "refs/remotes/${remote}/HEAD" 2>/dev/null)
  if [[ -n "$ref" ]]; then
    echo "${ref##*/}"
    return 0
  fi

  # Fall back to remote query (network call)
  branch=$(git remote show "$remote" 2>/dev/null | sed -n 's/.*HEAD branch: //p')
  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi

  __wt_err "cannot detect default branch for remote '$remote'"
  return 1
}

wt() {
  local cmd="${1:-switch}"
  shift 2>/dev/null

  case "$cmd" in
    create)  __wt_create "$@" ;;
    list)    __wt_list "$@" ;;
    switch)  __wt_switch "$@" ;;
    delete)  __wt_delete "$@" ;;
    help)    __wt_help ;;
    *)
      __wt_err "unknown command '$cmd'"
      __wt_help
      return 1
      ;;
  esac
}

__wt_help() {
  cat >&2 <<'EOF'
Usage: wt <command> [args]

Commands:
  create <name> [branch-ref]  Create a new worktree and switch to it
  list                        List all worktrees
  switch [name]               Switch to a worktree (fzf picker if no name)
  delete <name>               Delete a worktree with safety checks
  help                        Show this help message
EOF
}

__wt_create() {
  local name="$1"
  local branch_ref="$2"

  if [[ -z "$name" ]]; then
    __wt_err "usage: wt create <name> [branch-ref]"
    return 1
  fi

  local root
  root=$(__wt_repo_root) || return 1

  # Determine base ref
  local base_ref
  if [[ -n "$branch_ref" ]]; then
    # Validate the ref exists
    if ! git -C "$root" rev-parse --verify "$branch_ref" >/dev/null 2>&1; then
      __wt_err "ref '$branch_ref' does not exist"
      return 1
    fi
    base_ref="$branch_ref"
  else
    local remote
    remote=$(__wt_default_remote) || return 1
    local default_branch
    default_branch=$(__wt_default_branch "$remote") || return 1
    base_ref="${remote}/${default_branch}"
  fi

  # Determine branch name (increment if exists)
  local branch="$name"
  if git -C "$root" show-ref --verify --quiet "refs/heads/${branch}"; then
    local i=2
    while git -C "$root" show-ref --verify --quiet "refs/heads/${name}-${i}"; do
      i=$(( i + 1 ))
    done
    branch="${name}-${i}"
    __wt_err "Branch '$name' exists, using '$branch'"
  fi

  # Determine worktree path
  local wt_path="${root}/.worktrees/${name}"
  if [[ -d "$wt_path" ]]; then
    __wt_err "worktree '$name' already exists at $wt_path"
    return 1
  fi

  # Create the worktree (--no-track prevents auto-tracking the source ref,
  # so git push doesn't try to push to e.g. origin/main)
  if ! git -C "$root" worktree add -b "$branch" --no-track "$wt_path" "$base_ref"; then
    __wt_err "failed to create worktree"
    return 1
  fi

  __wt_err "Created worktree '$name' on branch '$branch' from '$base_ref'"
  cd "$wt_path" || return 1
}

__wt_list() {
  local root
  root=$(__wt_repo_root) || return 1
  git -C "$root" worktree list
}

__wt_switch() {
  local name="$1"

  local root
  root=$(__wt_repo_root) || return 1

  if [[ -z "$name" ]]; then
    name=$(git -C "$root" worktree list | fzf --prompt="worktree> " --height=50% --border-label=" select worktree ") || return 0
    name="${name%% *}"
    name="${name##*/}"
  fi

  # Parse git worktree list --porcelain to find a match
  local wt_path=""
  local current_path="" current_branch=""

  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        current_path="${line#worktree }"
        current_branch=""
        ;;
      "branch "*)
        # branch refs/heads/foo -> foo
        current_branch="${line#branch refs/heads/}"
        ;;
      "")
        # End of entry — check for match
        local basename="${current_path##*/}"
        if [[ "$basename" == "$name" || "$current_branch" == "$name" ]]; then
          wt_path="$current_path"
          break
        fi
        current_path=""
        current_branch=""
        ;;
    esac
  done < <(git -C "$root" worktree list --porcelain; echo "")

  if [[ -z "$wt_path" ]]; then
    __wt_err "no worktree matching '$name' found"
    return 1
  fi

  if [[ ! -d "$wt_path" ]]; then
    __wt_err "worktree directory '$wt_path' does not exist"
    return 1
  fi

  cd "$wt_path" || return 1
}

__wt_delete() {
  local name="$1"

  if [[ -z "$name" ]]; then
    __wt_err "usage: wt delete <name>"
    return 1
  fi

  local root
  root=$(__wt_repo_root) || return 1

  local wt_path="${root}/.worktrees/${name}"
  if [[ ! -d "$wt_path" ]]; then
    __wt_err "worktree '$name' does not exist at $wt_path"
    return 1
  fi

  # Detect the branch checked out in the worktree
  local branch
  branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

  # Check for uncommitted/unstaged changes
  local status
  status=$(git -C "$wt_path" status --porcelain 2>/dev/null)
  if [[ -n "$status" ]]; then
    __wt_err "worktree '$name' has uncommitted changes:"
    echo "$status" >&2
    __wt_err "refusing to delete — commit or discard changes first"
    return 1
  fi

  # Remove the worktree
  if ! git -C "$root" worktree remove "$wt_path"; then
    __wt_err "failed to remove worktree"
    return 1
  fi

  __wt_err "Removed worktree '$name'"

  # Branch cleanup
  if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
    # Check if branch has unpushed commits
    local upstream
    upstream=$(git -C "$root" rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null)

    local has_unpushed=false
    if [[ -n "$upstream" ]]; then
      local ahead
      ahead=$(git -C "$root" rev-list --count "${upstream}..${branch}" 2>/dev/null)
      if [[ "$ahead" -gt 0 ]]; then
        has_unpushed=true
      fi
    fi

    if [[ "$has_unpushed" == true ]]; then
      __wt_err "Warning: branch '$branch' has $ahead unpushed commit(s)"
      local reply
      echo -n "wt: Delete branch '$branch' anyway? [y/N] " >&2
      read -r reply
      if [[ "$reply" == [yY] ]]; then
        git -C "$root" branch -D "$branch"
        __wt_err "Deleted branch '$branch'"
      else
        __wt_err "Kept branch '$branch'"
      fi
    else
      # In sync or no upstream — safe to delete
      if git -C "$root" branch -d "$branch" 2>/dev/null; then
        __wt_err "Deleted branch '$branch'"
      else
        __wt_err "Note: could not delete branch '$branch' (may be the current branch)"
      fi
    fi
  fi

  # Prune stale worktree refs
  git -C "$root" worktree prune

  # If we were inside the deleted worktree, cd back to repo root
  local cwd
  cwd=$(pwd -P 2>/dev/null) || cwd=$(pwd)
  case "$cwd" in
    "${wt_path}"*)
      cd "$root" || return 1
      __wt_err "Changed directory to repo root"
      ;;
  esac
}
