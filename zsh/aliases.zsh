alias reload!='. ~/.zshrc'
alias cls='clear' # Good 'ol Clear Screen command
alias npm-update="npx npm-check -u"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
alias ls='exa'
alias ll='exa -lha'
alias lr='exa -lha --tree'
# Pipe my public key to my clipboard.
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | echo '=> Public key copied to pasteboard.'"
alias vim="nvim"
alias v="nvim ."
alias p="pnpm"
alias b="bun"
alias vim-config="nvim ~/.config/nvim/init.vim"
alias todo="reminders show todo"
# GH CLI specific ones
alias review-prs='gh pr list --search "is:open is:pr no:assignee"'

# Jira CLI specifc
alias j='jira sprint list --current -a$(jira me)'
alias jsprint='jira sprint list --current'
