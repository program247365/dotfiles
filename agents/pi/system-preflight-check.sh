#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/model_catalog.sh
source "$SCRIPT_DIR/lib/model_catalog.sh"

MODE="text"

usage() {
  cat <<'EOF'
Usage: system-preflight-check.sh [--json|--shell|--help]

Inspect this machine for Pi local model readiness and classify the
curated Ollama models as recommended, borderline, or not recommended.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json)
      MODE="json"
      ;;
    --shell)
      MODE="shell"
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

trim() {
  awk '{$1=$1; print}'
}

to_gb_int() {
  local raw="$1"
  local number unit
  number="$(printf '%s' "$raw" | awk '{print $1}')"
  unit="$(printf '%s' "$raw" | awk '{print $2}')"

  case "$unit" in
    TB|TiB)
      awk -v value="$number" 'BEGIN { printf "%d", value * 1024 }'
      ;;
    GB|GiB)
      awk -v value="$number" 'BEGIN { printf "%d", value }'
      ;;
    MB|MiB)
      awk -v value="$number" 'BEGIN { printf "%d", value / 1024 }'
      ;;
    *)
      printf '%s' "$number" | awk -F. '{print $1}'
      ;;
  esac
}

hardware_info="$(system_profiler SPHardwareDataType 2>/dev/null || true)"
chip="$(printf '%s\n' "$hardware_info" | awk -F': ' '/Chip:/ {print $2; exit}' | trim)"
memory_raw="$(printf '%s\n' "$hardware_info" | awk -F': ' '/Memory:/ {print $2; exit}' | trim)"
cpu_total="$(printf '%s\n' "$hardware_info" | awk -F': ' '/Total Number of Cores:/ {print $2; exit}' | awk '{print $1}')"

if [ -z "$chip" ]; then
  chip="$(uname -m)"
fi

if [ -z "$memory_raw" ]; then
  memory_raw="0 GB"
fi

if [ -z "$cpu_total" ]; then
  cpu_total="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
fi

ram_gb="$(to_gb_int "$memory_raw")"
disk_free_gb="$(df -Pk "$HOME" | awk 'NR==2 { printf "%d", $4 / 1024 / 1024 }')"
os_name="$(sw_vers -productName 2>/dev/null || uname -s)"
os_version="$(sw_vers -productVersion 2>/dev/null || uname -r)"
arch="$(uname -m)"

apple_silicon="no"
case "$chip" in
  Apple*) apple_silicon="yes" ;;
esac

ollama_installed="no"
if command -v ollama >/dev/null 2>&1; then
  ollama_installed="yes"
fi

apfel_installed="no"
if command -v apfel >/dev/null 2>&1; then
  apfel_installed="yes"
fi

pi_installed="no"
if command -v pi >/dev/null 2>&1; then
  pi_installed="yes"
fi

recommended_models=""
borderline_models=""
not_recommended_models=""
model_lines=""

for model_id in $(pi_model_ids); do
  classification="$(pi_model_classify "$model_id" "$ram_gb" "$cpu_total")"
  size_gb="$(pi_model_size_gb "$model_id")"
  min_ram_gb="$(pi_model_min_ram_gb "$model_id")"
  rec_ram_gb="$(pi_model_recommended_ram_gb "$model_id")"
  min_cpu_cores="$(pi_model_min_cpu_cores "$model_id")"
  rec_cpu_cores="$(pi_model_recommended_cpu_cores "$model_id")"
  context_window="$(pi_model_context "$model_id")"
  note="$(pi_model_use_case "$model_id")"

  case "$classification" in
    recommended)
      recommended_models="${recommended_models}${recommended_models:+ }$model_id"
      ;;
    borderline)
      borderline_models="${borderline_models}${borderline_models:+ }$model_id"
      ;;
    *)
      not_recommended_models="${not_recommended_models}${not_recommended_models:+ }$model_id"
      ;;
  esac

  model_lines="${model_lines}${model_id}|${classification}|${size_gb}|${min_ram_gb}|${rec_ram_gb}|${min_cpu_cores}|${rec_cpu_cores}|${context_window}|${note}
"
done

if [ "$MODE" = "shell" ]; then
  cat <<EOF
PI_PREFLIGHT_OS_NAME='$os_name'
PI_PREFLIGHT_OS_VERSION='$os_version'
PI_PREFLIGHT_ARCH='$arch'
PI_PREFLIGHT_CHIP='$chip'
PI_PREFLIGHT_APPLE_SILICON='$apple_silicon'
PI_PREFLIGHT_RAM_GB='$ram_gb'
PI_PREFLIGHT_CPU_TOTAL='$cpu_total'
PI_PREFLIGHT_DISK_FREE_GB='$disk_free_gb'
PI_PREFLIGHT_OLLAMA_INSTALLED='$ollama_installed'
PI_PREFLIGHT_APFEL_INSTALLED='$apfel_installed'
PI_PREFLIGHT_PI_INSTALLED='$pi_installed'
PI_PREFLIGHT_RECOMMENDED_MODELS='$recommended_models'
PI_PREFLIGHT_BORDERLINE_MODELS='$borderline_models'
PI_PREFLIGHT_NOT_RECOMMENDED_MODELS='$not_recommended_models'
EOF
  exit 0
fi

if [ "$MODE" = "json" ]; then
  printf '{\n'
  printf '  "osName": "%s",\n' "$os_name"
  printf '  "osVersion": "%s",\n' "$os_version"
  printf '  "arch": "%s",\n' "$arch"
  printf '  "chip": "%s",\n' "$chip"
  printf '  "appleSilicon": "%s",\n' "$apple_silicon"
  printf '  "ramGb": %s,\n' "$ram_gb"
  printf '  "cpuCores": %s,\n' "$cpu_total"
  printf '  "diskFreeGb": %s,\n' "$disk_free_gb"
  printf '  "ollamaInstalled": "%s",\n' "$ollama_installed"
  printf '  "apfelInstalled": "%s",\n' "$apfel_installed"
  printf '  "piInstalled": "%s",\n' "$pi_installed"
  printf '  "recommendedModels": "%s",\n' "$recommended_models"
  printf '  "borderlineModels": "%s",\n' "$borderline_models"
  printf '  "notRecommendedModels": "%s"\n' "$not_recommended_models"
  printf '}\n'
  exit 0
fi

cat <<EOF
Pi local-model preflight

Hardware
- OS: $os_name $os_version
- Arch: $arch
- Chip: $chip
- Apple Silicon: $apple_silicon
- Memory: ${ram_gb} GB
- CPU cores: $cpu_total
- Free disk in \$HOME volume: ${disk_free_gb} GB

Runtimes
- pi installed: $pi_installed
- ollama installed: $ollama_installed
- apfel installed: $apfel_installed

Recommended models
- ${recommended_models:-none}

Borderline models
- ${borderline_models:-none}

Not recommended models
- ${not_recommended_models:-none}

Model guide
EOF

printf '%s' "$model_lines" | while IFS='|' read -r model_id classification size_gb min_ram_gb rec_ram_gb min_cpu_cores rec_cpu_cores context_window note; do
  [ -n "$model_id" ] || continue
  cat <<EOF
- $model_id
  status: $classification
  size: ${size_gb} GB download
  context: $context_window
  minimum: ${min_ram_gb} GB RAM / ${min_cpu_cores}+ CPU cores
  better target: ${rec_ram_gb} GB RAM / ${rec_cpu_cores}+ CPU cores
  use: $note
EOF
done

cat <<'EOF'

Notes
- These thresholds are conservative so the bootstrap script does not push large models onto constrained machines.
- Memory is the primary limit on Apple Silicon. CPU guidance matters mainly for latency and responsiveness.
- Ollama downloads the model weights separately from Pi configuration. Having a model in `models.json` does not mean it is already installed.
EOF
