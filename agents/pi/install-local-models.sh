#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT_SCRIPT="$SCRIPT_DIR/system-preflight-check.sh"
# shellcheck source=./lib/model_catalog.sh
source "$SCRIPT_DIR/lib/model_catalog.sh"

DRY_RUN=0
INSTALL_OLLAMA=0
SELECTION_MODE="recommended"
EXPLICIT_MODELS=""

usage() {
  cat <<'EOF'
Usage: install-local-models.sh [options] [model ...]

Bootstrap the curated Ollama local models for Pi.

Options:
  --recommended    Install only recommended models for this machine (default).
  --safe           Alias for --recommended.
  --all-borderline Install recommended and borderline models.
  --install-ollama Install Ollama via Homebrew if it is missing.
  --dry-run        Print the plan without running `ollama pull`.
  -h, --help       Show help.
EOF
}

model_exists() {
  local target="$1"
  for model_id in $(pi_model_ids); do
    if [ "$model_id" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

append_unique_model() {
  local model_id="$1"
  local current="${2:-}"

  case " $current " in
    *" $model_id "*) printf '%s' "$current" ;;
    *) printf '%s' "${current}${current:+ }$model_id" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --recommended|--safe)
      SELECTION_MODE="recommended"
      ;;
    --all-borderline)
      SELECTION_MODE="all-borderline"
      ;;
    --install-ollama)
      INSTALL_OLLAMA=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if ! model_exists "$1"; then
        echo "Unknown model: $1" >&2
        printf 'Supported models:\n' >&2
        pi_model_ids >&2
        exit 1
      fi
      EXPLICIT_MODELS="$(append_unique_model "$1" "$EXPLICIT_MODELS")"
      ;;
  esac
  shift
done

eval "$(bash "$PREFLIGHT_SCRIPT" --shell)"

if [ "$PI_PREFLIGHT_OLLAMA_INSTALLED" != "yes" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Ollama is not installed. Continuing because --dry-run was requested."
    echo ""
  elif [ "$INSTALL_OLLAMA" -eq 1 ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is required for --install-ollama but was not found." >&2
      exit 1
    fi
    echo "Installing Ollama via Homebrew..."
    brew install ollama
  else
    cat <<'EOF' >&2
Ollama is not installed.

Install it with:
  brew install ollama

Then start it:
  ollama serve

Or rerun this script with:
  ~/.dotfiles/agents/pi/install-local-models.sh --install-ollama
EOF
    exit 1
  fi
fi

if [ "$PI_PREFLIGHT_OLLAMA_INSTALLED" = "yes" ] || command -v ollama >/dev/null 2>&1; then
  PI_PREFLIGHT_OLLAMA_INSTALLED="yes"
fi

if [ "$PI_PREFLIGHT_OLLAMA_INSTALLED" != "yes" ] && [ "$DRY_RUN" -ne 1 ]; then
  echo "Ollama is still unavailable after setup." >&2
  exit 1
fi

selected_models=""

if [ -n "$EXPLICIT_MODELS" ]; then
  selected_models="$EXPLICIT_MODELS"
elif [ "$SELECTION_MODE" = "all-borderline" ]; then
  selected_models="$PI_PREFLIGHT_RECOMMENDED_MODELS $PI_PREFLIGHT_BORDERLINE_MODELS"
else
  selected_models="$PI_PREFLIGHT_RECOMMENDED_MODELS"
fi

selected_models="$(printf '%s\n' "$selected_models" | xargs 2>/dev/null || true)"

if [ -z "$selected_models" ]; then
  echo "No models matched the current selection on this machine." >&2
  exit 1
fi

installed_models=""
if command -v ollama >/dev/null 2>&1; then
  installed_models="$(ollama list 2>/dev/null | awk 'NR > 1 {print $1}' | tr '\n' ' ' | xargs 2>/dev/null || true)"
fi

echo "Pi local model bootstrap"
echo ""
echo "Machine"
echo "- chip: $PI_PREFLIGHT_CHIP"
echo "- memory: ${PI_PREFLIGHT_RAM_GB} GB"
echo "- cpu cores: $PI_PREFLIGHT_CPU_TOTAL"
echo "- free disk: ${PI_PREFLIGHT_DISK_FREE_GB} GB"
echo ""
echo "Selection"
for model_id in $selected_models; do
  classification="$(pi_model_classify "$model_id" "$PI_PREFLIGHT_RAM_GB" "$PI_PREFLIGHT_CPU_TOTAL")"
  size_gb="$(pi_model_size_gb "$model_id")"
  min_ram_gb="$(pi_model_min_ram_gb "$model_id")"
  rec_ram_gb="$(pi_model_recommended_ram_gb "$model_id")"
  min_cpu_cores="$(pi_model_min_cpu_cores "$model_id")"
  rec_cpu_cores="$(pi_model_recommended_cpu_cores "$model_id")"
  note="$(pi_model_use_case "$model_id")"
  cat <<EOF
- $model_id
  status: $classification
  size: ${size_gb} GB download
  minimum: ${min_ram_gb} GB RAM / ${min_cpu_cores}+ CPU cores
  better target: ${rec_ram_gb} GB RAM / ${rec_cpu_cores}+ CPU cores
  reason: $note
  command: ollama pull $model_id
EOF
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "Dry run only. No models were pulled."
  exit 0
fi

echo ""
printf "Proceed with these pulls? [y/N] "
read -r answer
case "$answer" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Aborted."
    exit 0
    ;;
esac

for model_id in $selected_models; do
  case " $installed_models " in
    *" $model_id "*)
      echo "Skipping $model_id (already installed)"
      continue
      ;;
  esac

  required_disk_gb="$(awk -v value="$(pi_model_size_gb "$model_id")" 'BEGIN { printf "%d", value + 2 }')"
  if [ "$PI_PREFLIGHT_DISK_FREE_GB" -lt "$required_disk_gb" ]; then
    echo "Skipping $model_id (needs about ${required_disk_gb} GB free disk, found ${PI_PREFLIGHT_DISK_FREE_GB} GB)"
    continue
  fi

  echo "Pulling $model_id..."
  ollama pull "$model_id"
done

cat <<'EOF'

Next steps
- Start Pi and use `/model` or `Ctrl+L` to select the local model.
- Use `Ctrl+P` to cycle your enabled model shortlist.
- If you also want the Apple on-device model, install and run `apfel --serve`, then update `~/.pi/agent/models.json` if the port differs from the default example.
EOF
