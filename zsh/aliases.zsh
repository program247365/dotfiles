alias reload!='. ~/.zshrc'
alias cls='clear' # Good 'ol Clear Screen command
alias npm-update="npx npm-check -u"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
alias ls='eza'
alias ll='eza -lha'
alias lr='eza -lha --tree'
# Pipe my public key to my clipboard.
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | echo '=> Public key copied to pasteboard.'"
alias vim="nvim"
alias n="nvim"
alias p="pnpm"
alias b="bun"
alias bx="bunx"
alias vim-config="nvim ~/.config/nvim/init.vim"
alias todo="reminders show todo"
# GH CLI specific ones
alias review-prs='gh pr list --search "is:open is:pr no:assignee"'

# Jira CLI specifc
alias j='jira sprint list --table --plain --current -a$(jira me)'
alias jsprint='jira sprint list --current'
alias jpsprint='jira sprint list --prev -a$(jira me) --plain --no-headers --columns KEY,SUMMARY | tee >(pbcopy)'
alias jtix='jira sprint list --plain --current -a$(jira me) --columns key,summary --no-headers --order-by priority | tee >(pbcopy)'

# Terraform specific
alias tf='terraform'
alias tfc='terraform console'
alias tff='terraform fmt'
alias tfg='terraform graph'
alias tfi='terraform init'
alias tfo='terraform output'
alias tfp='terraform plan'
alias tfr='terraform refresh'
alias tfv='terraform validate'

# Fzf make
alias fm='fzf-make'
alias fr='fzf-make repeat'
alias fh='fzf-make history'

# My Apps
alias r='rem-tui'
alias q='qmd'

# Wrap claude to auto-update and auto-rename the Warp tab while it's running.
# In Warp, disable auto-title so OSC 0 sticks across split panes.
function claude() {
  local project prev_auto_title
  project="$(basename "$PWD")"

  # Auto-update via brew (check at most once per hour)
  if [[ "$1" != "--help" && "$1" != "-h" && "$1" != "--version" ]]; then
    local cache_file="$HOME/.claude/.update_check"
    local now=$(date +%s)
    local last_check=0
    [[ -f "$cache_file" ]] && last_check=$(cat "$cache_file")

    if (( now - last_check >= 3600 )); then
      echo "$now" > "$cache_file"
      if HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --formula | grep -q '^claude-code$'; then
        local cur_ver
        cur_ver=$(command claude --version 2>/dev/null | head -1)
        HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade claude-code
        local new_ver semver release_url
        new_ver=$(command claude --version 2>/dev/null | head -1)
        semver=$(echo "$new_ver" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        release_url="https://github.com/anthropics/claude-code/releases/tag/v${semver}"
        echo "Updated $cur_ver → $new_ver — $release_url"
      fi
    fi
  fi

  if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
    prev_auto_title="${WARP_DISABLE_AUTO_TITLE:-}"
    export WARP_DISABLE_AUTO_TITLE="true"
  fi

  printf "\033]0;Claude | %s\007" "$project"
  command claude "$@"
  printf "\033]0;%s\007" "$project"

  if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
    if [[ -n "$prev_auto_title" ]]; then
      export WARP_DISABLE_AUTO_TITLE="$prev_auto_title"
    else
      unset WARP_DISABLE_AUTO_TITLE
    fi
  fi
}
