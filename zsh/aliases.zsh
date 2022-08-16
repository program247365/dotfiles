alias reload!='. ~/.zshrc'
alias cls='clear' # Good 'ol Clear Screen command
alias npm-update="npx npm-check -u"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder"
alias ls='exa'
alias ll='exa -lha'
alias lr='exa -lha --tree'
# Pipe my public key to my clipboard.
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | echo '=> Public key copied to pasteboard.'"
