# portless - https://port1355.dev/
# Named .localhost URLs for dev servers instead of random ports.
# Proxy runs on port 1355; apps get random ports in 4000-4999 range.
#
# Usage:
#   portless myapp pnpm dev     → http://myapp.localhost:1355
#   portless api.myapp npm start → http://api.myapp.localhost:1355
#   plps --https                 → start proxy with HTTPS (one-time cert setup)

alias pl='portless'
alias plps='portless proxy start'
alias plph='portless proxy start --https'
alias plpl='portless proxy list'
alias plpk='portless proxy stop'
