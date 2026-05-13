# Powerlevel10k config tuned to mimic oh-my-zsh agnoster.
#
# Segments (left-to-right, matching agnoster):
#   status   — red ✘ shown only on non-zero exit
#   context  — user@host on black bg (hidden when local & default user)
#   dir      — blue bg, black fg
#   vcs      — green bg when clean, yellow bg when dirty (black fg)
# Right prompt is intentionally empty; zshrc sets RPROMPT='$(kube_ps1)'.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    status
    context
    dir
    vcs
  )
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_ICON_PADDING=none
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  # Powerline arrow separators (the agnoster glyphs).
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$''
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=$''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=$''
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$''
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=$''

  # ---- status: ✘ on failure only ----
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=white
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=red
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=white
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND=red
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_VERBOSE=false

  # ---- context: user@host on black ----
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND=default
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND=black
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND=black
  typeset -g POWERLEVEL9K_CONTEXT_REMOTE_FOREGROUND=default
  typeset -g POWERLEVEL9K_CONTEXT_REMOTE_BACKGROUND=black
  typeset -g POWERLEVEL9K_CONTEXT_REMOTE_SUDO_FOREGROUND=default
  typeset -g POWERLEVEL9K_CONTEXT_REMOTE_SUDO_BACKGROUND=black
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
  # Hide on local non-root sessions — same trigger as agnoster.
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_CONTENT_EXPANSION=
  typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_CONTEXT_SUDO_CONTENT_EXPANSION=
  typeset -g POWERLEVEL9K_CONTEXT_SUDO_VISUAL_IDENTIFIER_EXPANSION=

  # ---- dir: blue bg, black fg ----
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=black
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=blue
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3
  # No folder glyph — agnoster doesn't have one.
  typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=

  # ---- vcs (git): green clean / yellow dirty, black fg ----
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=black
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=green
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=black
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=black
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=black
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=black
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=green

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=''
  typeset -g POWERLEVEL9K_VCS_COMMIT_ICON='➦ '
  typeset -g POWERLEVEL9K_VCS_STAGED_ICON='✚'
  typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON='●'
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='…'
  typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON='⇣'
  typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON='⇡'
  typeset -g POWERLEVEL9K_VCS_STASH_ICON='⚑'
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_ICON='✖'

  # Match agnoster: no ahead/behind indicator.
  typeset -g POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-stash)
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
}

# Restore caller's options. Must run OUTSIDE the anonymous function above,
# whose `emulate -L zsh` localizes setopt changes.
(( ! $#p10k_config_opts )) || setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
