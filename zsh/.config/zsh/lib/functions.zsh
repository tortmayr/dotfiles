# Portable shell functions. Functions that drive a desktop application
# (clipboard managers, notification daemons, ...) belong in host.d/ instead.

openLazygit() {
  local gitdir
  if [[ -n "$1" ]] && git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Use the provided directory argument
    gitdir=$(git -C "$1" rev-parse --show-toplevel)
  elif [[ -z "$1" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # No argument and inside a git repo — use current repo
    gitdir=$(git rev-parse --show-toplevel)
  else
    # Fall back to interactive selection
    gitdir=$(sgit)
  fi

  # Check if the selected or provided directory is a valid git repository
  if [[ -n "$gitdir" ]] && git -C "$gitdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch_before=$(git -C "$gitdir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    lazygit -p "$gitdir"
    local branch_after=$(git -C "$gitdir" rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Signal parent shell to refresh prompt if branch changed (when opened from tmux popup)
    if [[ -n "$PARENT_PID" && "$branch_before" != "$branch_after" ]]; then
      kill -USR1 "$PARENT_PID" 2>/dev/null
    fi
  else
    echo "No valid git directory selected."
  fi
}

# Execute a shell script or binary file selected with fzf
es() {
  local selected
  selected=$(find . -maxdepth 1 -type f -executable \
    -exec file {} + \
    | grep -E ':.*(shell script|ELF)' \
    | cut -d: -f1 \
    | fzf --height=40% \
          --prompt="Select shell script > " \
          --preview 'bat --style=plain --color=always {} || echo "binary file"' \
          --preview-window=right:70%)
  [[ -n "$selected" ]] && print -z "$selected"
}

timezsh() {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time "$shell" -i -c exit; done
}

# Needs a populated man page database; slim container images ship none.
fman() {
  man -k . | fzf -q "$1" --prompt='man> ' --preview $'echo {} | tr -d \'()\' | awk \'{printf "%s ", $2} {print $1}\' | xargs -r man | col -bx | bat -l man -p --color always' | tr -d '()' | awk '{printf "%s ", $2} {print $1}' | xargs -r man
}
