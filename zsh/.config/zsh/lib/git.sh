# Interactive git repository pickers. Sourced by .zshrc, and by standalone
# bash scripts, so it must not rely on anything .zshrc sets: USER_GIT_DIR
# falls back on its own.

# Print the path of a git repository selected with fzf, searched below
# $USER_GIT_DIR (default: ~/Git).
selectGit() {
  local gitRoot="${USER_GIT_DIR:-$HOME/Git}"
  local gitDir
  gitDir=$(fd --hidden --type d --glob ".git" --no-ignore-vcs "$gitRoot" -x dirname | \
    fzf --prompt "Select git dir: " \
        --preview 'eza -ah -1 --color=always --icons {}' \
        --height=50%)

  echo "$gitDir"
}

# Change directory to a git repository selected with fzf from $USER_GIT_DIR.
cdGit() {
  selected_dir=$(selectGit)

  # If a directory is selected, cd into it
  if [ -n "$selected_dir" ]; then
    cd "$selected_dir" || return 1
  else
    echo "No git directory selected."
  fi
}
