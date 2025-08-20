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

# My Apps
alias r='rem-tui'
