# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# zmodload zsh/zprof
# ----- General zsh options ------------------------------------------------------------

setopt appendhistory                # Append history instead of overwrite => global history between sessions
setopt autocd  nomatch
setopt interactive_comments         # Allow comments in interactive shell
[[ -t 0 ]] && stty stop undef      # Disable ctrl-s freeze only when stdin is a TTY.
zle_highlight=('paste:none')        # Disable highlighting of pasted text

# Completion options
unsetopt flowcontrol                # Disable Ctrl-S and Ctrl-Q
setopt complete_in_word             # allow completion within a word
setopt always_to_end                # move cursor to the end of a completed word

# ----- History configuration ------------------------------------------------------------
# HISTFILE is overridable from host.d: an enclave container, for example, only
# persists a specific mounted directory across sessions.
HISTFILE=~/.zsh_history
HISTSIZE=1000000              # Increase history size
SAVEHIST=1000000              # Increase history size

setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data


# ----- Key bindings ------------------------------------------------------------

# terminfo lookups come back empty when the terminal has no entry for a key
# (a bare container TTY, TERM=dumb, ...), and bindkey then errors out on every
# shell start. Bind only what the terminal actually reports.
bindkey_terminfo() {
  [[ -n "${terminfo[$1]}" ]] && bindkey "${terminfo[$1]}" "$2"
}

autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search
bindkey_terminfo kcuu1 up-line-or-beginning-search          # Start typing + [Up-Arrow] - fuzzy find history forward

autoload -U down-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey_terminfo kcud1 down-line-or-beginning-search        # Start typing + [Down-Arrow] - fuzzy find history backward

bindkey_terminfo kpp up-line-or-history                     # [PageUp] - Up a line of history
bindkey_terminfo knp down-line-or-history                   # [PageDown] - Down a line of history
bindkey '^[[1;5C' forward-word                              # [Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word                             # [Ctrl-LeftArrow] - move backward one word

# [Ctrl-L] - real clear: wipe screen AND scrollback (tmux-style), instead of
# the kitty/ghostty/herdr default that scrolls the screen into scrollback.
ctrl_l() {
    builtin print -rn -- $'\e[H\e[3J' >"$TTY"
    builtin zle .reset-prompt
    builtin zle -R
}
zle -N ctrl_l
bindkey '^l' ctrl_l

# ----- Zsh additions ------------------------------------------------------------
source "$ZDOTDIR/lib/exports.zsh"
source "$ZDOTDIR/lib/aliases.zsh"
source "$ZDOTDIR/lib/functions.zsh"
source "$ZDOTDIR/lib/setup.zsh"
source "$SCRIPT_LIBRARY_DIR/worktree.sh"
source "$SCRIPT_LIBRARY_DIR/git.sh"

# ----- Machine-specific layers --------------------------------------------------
# host.d:  tracked per-machine config (desktop tools, work paths, editor choice).
# local.d: untracked machine-local config (secrets, client-specific paths).
# Both are optional: the (N) glob qualifier makes a missing directory a no-op,
# which is what lets this same file run unchanged inside a container.
for _zshrc_layer in "$ZDOTDIR"/host.d/*.zsh(N) "$ZDOTDIR"/local.d/*.zsh(N); do
  source "$_zshrc_layer"
done
unset _zshrc_layer

# -----Additional setup ---------------------------------------------------------
setup_zsh_completion
setup_fzf
setup_nvm_lazy_loading

# ----- Zsh prompt theme configuration ----------------------------------------
source "$ZDOTDIR/plugins/powerlevel10k/powerlevel10k.zsh-theme"

# ----- Zsh plugins -----------------------------------------------------------
source "$ZDOTDIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$ZDOTDIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"


# To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ ! -f "$ZDOTDIR/.p10k.zsh" ]] || source "$ZDOTDIR/.p10k.zsh"
