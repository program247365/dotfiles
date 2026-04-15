#!/usr/bin/env bash

# Shared local model metadata for Pi bootstrap scripts.

pi_model_ids() {
  cat <<'EOF'
qwen2.5-coder:7b
qwen2.5-coder:14b
gemma4:e2b
gemma4:e4b
gpt-oss:20b
qwen3-coder:30b
qwen2.5-coder:32b
EOF
}

pi_model_runtime() {
  case "$1" in
    qwen2.5-coder:7b|qwen2.5-coder:14b|gemma4:e2b|gemma4:e4b|gpt-oss:20b|qwen3-coder:30b|qwen2.5-coder:32b) echo "ollama" ;;
    *) return 1 ;;
  esac
}

pi_model_label() {
  case "$1" in
    qwen2.5-coder:7b) echo "Qwen 2.5 Coder 7B" ;;
    qwen2.5-coder:14b) echo "Qwen 2.5 Coder 14B" ;;
    gemma4:e2b) echo "Gemma 4 E2B" ;;
    gemma4:e4b) echo "Gemma 4 E4B" ;;
    gpt-oss:20b) echo "gpt-oss 20B" ;;
    qwen3-coder:30b) echo "Qwen 3 Coder 30B" ;;
    qwen2.5-coder:32b) echo "Qwen 2.5 Coder 32B" ;;
    *) return 1 ;;
  esac
}

pi_model_size_gb() {
  case "$1" in
    qwen2.5-coder:7b) echo "4.7" ;;
    qwen2.5-coder:14b) echo "9.0" ;;
    gemma4:e2b) echo "7.2" ;;
    gemma4:e4b) echo "9.6" ;;
    gpt-oss:20b) echo "14" ;;
    qwen3-coder:30b) echo "19" ;;
    qwen2.5-coder:32b) echo "20" ;;
    *) return 1 ;;
  esac
}

pi_model_context() {
  case "$1" in
    qwen2.5-coder:7b|qwen2.5-coder:14b|qwen2.5-coder:32b) echo "32K" ;;
    gemma4:e2b|gemma4:e4b) echo "128K" ;;
    gpt-oss:20b) echo "128K" ;;
    qwen3-coder:30b) echo "256K" ;;
    *) return 1 ;;
  esac
}

pi_model_min_ram_gb() {
  case "$1" in
    qwen2.5-coder:7b) echo "8" ;;
    gemma4:e2b) echo "8" ;;
    gemma4:e4b) echo "12" ;;
    qwen2.5-coder:14b) echo "16" ;;
    gpt-oss:20b) echo "16" ;;
    qwen3-coder:30b|qwen2.5-coder:32b) echo "24" ;;
    *) return 1 ;;
  esac
}

pi_model_recommended_ram_gb() {
  case "$1" in
    qwen2.5-coder:7b) echo "16" ;;
    gemma4:e2b) echo "12" ;;
    gemma4:e4b) echo "18" ;;
    qwen2.5-coder:14b) echo "24" ;;
    gpt-oss:20b) echo "24" ;;
    qwen3-coder:30b|qwen2.5-coder:32b) echo "32" ;;
    *) return 1 ;;
  esac
}

pi_model_min_cpu_cores() {
  case "$1" in
    qwen2.5-coder:7b|gemma4:e2b) echo "4" ;;
    gemma4:e4b|qwen2.5-coder:14b) echo "6" ;;
    gpt-oss:20b) echo "8" ;;
    qwen3-coder:30b|qwen2.5-coder:32b) echo "10" ;;
    *) return 1 ;;
  esac
}

pi_model_recommended_cpu_cores() {
  case "$1" in
    qwen2.5-coder:7b|gemma4:e2b) echo "8" ;;
    gemma4:e4b|qwen2.5-coder:14b) echo "8" ;;
    gpt-oss:20b) echo "12" ;;
    qwen3-coder:30b|qwen2.5-coder:32b) echo "12" ;;
    *) return 1 ;;
  esac
}

pi_model_use_case() {
  case "$1" in
    qwen2.5-coder:7b) echo "Best everyday local coding default" ;;
    qwen2.5-coder:14b) echo "Higher-quality coding model if you have memory headroom" ;;
    gemma4:e2b) echo "Fastest local fallback with strong context length" ;;
    gemma4:e4b) echo "Balanced local reasoning and coding model" ;;
    gpt-oss:20b) echo "Strong agentic local model, but heavy on 16 GB machines" ;;
    qwen3-coder:30b) echo "Very strong coding model, but too large for 16 GB Apple Silicon" ;;
    qwen2.5-coder:32b) echo "Legacy larger Qwen coding option, workstation-class memory" ;;
    *) return 1 ;;
  esac
}

pi_model_classify() {
  local model_id="$1"
  local ram_gb="$2"
  local cpu_cores="$3"
  local min_ram_gb rec_ram_gb min_cpu_cores rec_cpu_cores

  min_ram_gb="$(pi_model_min_ram_gb "$model_id")"
  rec_ram_gb="$(pi_model_recommended_ram_gb "$model_id")"
  min_cpu_cores="$(pi_model_min_cpu_cores "$model_id")"
  rec_cpu_cores="$(pi_model_recommended_cpu_cores "$model_id")"

  if [ "$ram_gb" -ge "$rec_ram_gb" ] && [ "$cpu_cores" -ge "$rec_cpu_cores" ]; then
    echo "recommended"
    return 0
  fi

  if [ "$ram_gb" -ge "$min_ram_gb" ] && [ "$cpu_cores" -ge "$min_cpu_cores" ]; then
    echo "borderline"
    return 0
  fi

  echo "not-recommended"
}
