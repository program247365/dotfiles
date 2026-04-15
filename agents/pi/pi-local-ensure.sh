#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/model_catalog.sh
source "$SCRIPT_DIR/lib/model_catalog.sh"

usage() {
  cat <<'EOF'
Usage: pi-local-ensure.sh <model> [-- pi args...]

Ensure an Ollama model is installed locally, then launch Pi.

Examples:
  pi-local-ensure.sh qwen2.5-coder:7b
  pi-local-ensure.sh qwen2.5-coder:7b -- --model qwen2.5-coder:7b
EOF
}

model_exists_in_catalog() {
  local target="$1"
  local model_id
  for model_id in $(pi_model_ids); do
    if [ "$model_id" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

if [ $# -lt 1 ]; then
  usage >&2
  exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

MODEL_ID="$1"
shift

PI_ARGS=()
if [ $# -gt 0 ]; then
  if [ "$1" = "--" ]; then
    shift
  fi
  PI_ARGS=("$@")
fi

if ! command -v pi >/dev/null 2>&1; then
  echo "Pi is not installed." >&2
  echo "Run: sh ~/.dotfiles/agents/pi/install.sh" >&2
  exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed." >&2
  echo "Run: sh ~/.dotfiles/agents/pi/install.sh --install-ollama" >&2
  exit 1
fi

if ! curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "Ollama is installed but not responding on http://127.0.0.1:11434." >&2
  echo "Run: ollama serve" >&2
  echo "Or rerun: sh ~/.dotfiles/agents/pi/install.sh --install-ollama" >&2
  exit 1
fi

if ! ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq "$MODEL_ID"; then
  echo "Model '$MODEL_ID' is not installed in Ollama."

  if model_exists_in_catalog "$MODEL_ID"; then
    cat <<EOF
- size: $(pi_model_size_gb "$MODEL_ID") GB download
- minimum: $(pi_model_min_ram_gb "$MODEL_ID") GB RAM / $(pi_model_min_cpu_cores "$MODEL_ID")+ CPU cores
- better target: $(pi_model_recommended_ram_gb "$MODEL_ID") GB RAM / $(pi_model_recommended_cpu_cores "$MODEL_ID")+ CPU cores
- use: $(pi_model_use_case "$MODEL_ID")
EOF
  else
    echo "- this model is not in the repo's curated catalog, so no local sizing guidance is available"
  fi

  echo ""
  echo "Command:"
  echo "  ollama pull $MODEL_ID"
  echo ""
  printf "Pull it now? [y/N] "
  read -r answer
  case "$answer" in
    y|Y|yes|YES)
      ollama pull "$MODEL_ID"
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

echo "Launching Pi..."
exec pi "${PI_ARGS[@]}"
