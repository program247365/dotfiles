# OrbStack serves Docker at ~/.orbstack/run/docker.sock, not /var/run/docker.sock
# (that symlink needs OrbStack's admin mode). Local CI ignores docker contexts and
# DOCKER_HOST, so point it at the socket directly.
if [[ -S "$HOME/.orbstack/run/docker.sock" ]]; then
  export LOCAL_CI_DOCKER_HOST="unix://$HOME/.orbstack/run/docker.sock"
fi
