#!/usr/bin/env bash

set -euo pipefail

INSTALL_OLLAMA=0

usage() {
  cat <<'EOF'
Usage: install.sh [--install-ollama|--with-ollama] [--help]

Install Pi via pnpm and seed local Pi configuration.

Options:
  --install-ollama, --with-ollama  Install Ollama via Homebrew if it is missing, then ensure the local API is running.
  -h, --help                       Show help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --install-ollama|--with-ollama)
      INSTALL_OLLAMA=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

echo "Setting up Pi..."

DOTFILES_ROOT="${HOME}/.dotfiles"
DOTFILES_PI="${DOTFILES_ROOT}/agents/pi"
PI_DIR="${HOME}/.pi"
PI_AGENT_DIR="${PI_DIR}/agent"
KEVIN_BIN_DIR="${HOME}/.kevin/bin"
SHELL_ZSH_SOURCE="source \"$DOTFILES_ROOT/agents/shell.zsh\""

mkdir -p "${PI_AGENT_DIR}"
mkdir -p "${KEVIN_BIN_DIR}"

link_with_backup() {
  local source="$1"
  local target="$2"
  local label="$3"
  local current_target=""
  local backup=""

  if [ -L "${target}" ]; then
    current_target="$(readlink "${target}")"
    if [ "${current_target}" = "${source}" ]; then
      echo "  ${label} already linked"
      return
    fi
    rm "${target}"
  elif [ -e "${target}" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${target}" "${backup}"
    echo "  Backed up existing ${label} to ${backup}"
  fi

  ln -s "${source}" "${target}"
  echo "  Linked ${label}"
}

copy_if_missing() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [ -e "${target}" ]; then
    echo "  Keeping existing ${label}"
    return
  fi

  cp "${source}" "${target}"
  echo "  Seeded ${label} from defaults"
}

ollama_responding() {
  curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null 2>&1
}

ensure_ollama_running() {
  if ollama_responding; then
    echo "  Ollama API already responding"
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "  Starting Ollama via brew services..."
    brew services start ollama >/dev/null
  else
    echo "  Starting Ollama in the background..."
    nohup ollama serve >/tmp/ollama.log 2>&1 &
  fi

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ollama_responding; then
      echo "  Ollama API is running"
      return
    fi
    sleep 1
  done

  echo "  Error: Ollama did not start successfully on http://127.0.0.1:11434" >&2
  echo "  Try running: ollama serve" >&2
  exit 1
}

if ! command -v pnpm >/dev/null 2>&1; then
  echo "  Error: pnpm not found. Run mise use --global pnpm@latest first." >&2
  exit 1
fi

if [ "$INSTALL_OLLAMA" -eq 1 ]; then
  if command -v ollama >/dev/null 2>&1; then
    echo "  Ollama already installed"
  else
    if ! command -v brew >/dev/null 2>&1; then
      echo "  Error: Homebrew is required to install Ollama automatically." >&2
      exit 1
    fi
    echo "  Installing Ollama via Homebrew..."
    brew install ollama
  fi

  ensure_ollama_running
fi

echo "  Installing Pi via pnpm..."
pnpm add -g @mariozechner/pi-coding-agent

PNPM_BIN_DIR="$(pnpm bin -g)"
if [ ! -x "${PNPM_BIN_DIR}/pi" ]; then
  echo "  Error: pi binary not found in ${PNPM_BIN_DIR}" >&2
  exit 1
fi

ln -sf "${PNPM_BIN_DIR}/pi" "${KEVIN_BIN_DIR}/pi"
echo "  Linked ~/.kevin/bin/pi"

link_with_backup "${DOTFILES_PI}/home/settings.json" "${PI_AGENT_DIR}/settings.json" "~/.pi/agent/settings.json"
link_with_backup "${DOTFILES_PI}/home/AGENTS.md" "${PI_AGENT_DIR}/AGENTS.md" "~/.pi/agent/AGENTS.md"
copy_if_missing "${DOTFILES_PI}/home/models.json.default" "${PI_AGENT_DIR}/models.json" "~/.pi/agent/models.json"

if ! grep -qF "${SHELL_ZSH_SOURCE}" "${HOME}/.zshrc.local" 2>/dev/null; then
  echo "${SHELL_ZSH_SOURCE}" >> "${HOME}/.zshrc.local"
  echo "  Added shell.zsh source to ~/.zshrc.local"
else
  echo "  shell.zsh already sourced in ~/.zshrc.local"
fi

cat <<'EOF'
  Pi install complete.
  Next steps:
    ~/.dotfiles/agents/pi/system-preflight-check.sh
    ~/.dotfiles/agents/pi/install-local-models.sh --recommended
    ollama serve    # if you installed Ollama and want local models
EOF

echo "Done setting up Pi"
