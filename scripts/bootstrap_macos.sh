#!/usr/bin/env bash
# bootstrap_macos.sh — install ComfyUI + 3D models on Apple Silicon Mac.
# Target: M1 Ultra 128GB (MPS). Tested on macOS 14+.
set -euo pipefail

GREEN=$'\033[1;32m'; RED=$'\033[1;31m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
log()  { echo "${GREEN}→${NC} $*"; }
warn() { echo "${YELLOW}!${NC} $*"; }
err()  { echo "${RED}✗${NC} $*" >&2; }

# --- 0. Preconditions -------------------------------------------------------
[[ "$(uname)" == "Darwin" ]] || { err "This script targets macOS. For Linux use comfy --skip-prompt install --nvidia."; exit 1; }
[[ "$(uname -m)" == "arm64" ]] || { err "Need Apple Silicon (arm64). Intel Macs unsupported — use Comfy Cloud."; exit 1; }

command -v python3 >/dev/null || { err "python3 not found. Install Xcode CLT: xcode-select --install"; exit 1; }
command -v brew   >/dev/null || { warn "Homebrew not found — installing..."; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }

# --- 1. comfy-cli -----------------------------------------------------------
if ! command -v comfy >/dev/null 2>&1; then
  log "Installing comfy-cli via pipx"
  if ! command -v pipx >/dev/null 2>&1; then
    brew install pipx
    pipx ensurepath
  fi
  pipx install comfy-cli
  # pipx binaries land in ~/.local/bin
  export PATH="$HOME/.local/bin:$PATH"
  grep -q '.local/bin' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
fi

comfy --skip-prompt tracking disable >/dev/null 2>&1 || true

# --- 2. ComfyUI install (M-series / MPS) -----------------------------------
WORKSPACE="${COMFY_WORKSPACE:-$HOME/comfy}"
if [ ! -d "$WORKSPACE/ComfyUI" ]; then
  log "Installing ComfyUI at $WORKSPACE (--m-series, MPS)"
  comfy --workspace "$WORKSPACE" --skip-prompt install --m-series --fast-deps
else
  log "ComfyUI already present at $WORKSPACE — skipping install"
fi

# --- 3. Launch server in background ----------------------------------------
if ! curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
  log "Launching ComfyUI server on :8188"
  comfy --workspace "$WORKSPACE" launch --background >/tmp/comfyui-launch.log 2>&1 || {
    err "Server failed to start. See /tmp/comfyui-launch.log"
    tail -30 /tmp/comfyui-launch.log
    exit 1
  }
  # wait for readiness
  for i in {1..30}; do
    curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1 && break
    sleep 2
  done
fi

if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
  log "Server reachable: http://127.0.0.1:8188"
else
  err "Server not reachable after 60s"
  exit 1
fi

# --- 4. Custom nodes for 3D ------------------------------------------------
log "Installing 3D custom nodes"
NODES=(
  "ComfyUI-Hunyuan3D-2"      # Tencent Hunyuan3D-2 wrapper
  "ComfyUI-TRELLIS"          # Microsoft TRELLIS
  "ComfyUI-TripoSR"          # Stability TripoSR
  "comfyui-essentials"       # helpers
)
for node in "${NODES[@]}"; do
  comfy --workspace "$WORKSPACE" node install "$node" 2>&1 | tail -2 || warn "Failed to install $node"
done

# --- 5. Download models ----------------------------------------------------
# Hunyuan3D-2 — Tencent (HuggingFace)
log "Downloading Hunyuan3D-2 weights (~14GB)"
comfy --workspace "$WORKSPACE" model download \
  --url "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-dit-fp16.safetensors" \
  --relative-path models/hunyuan3d2 2>&1 | tail -3 || warn "Hunyuan3D-2 download failed (resume with same command)"

comfy --workspace "$WORKSPACE" model download \
  --url "https://huggingface.co/tencent/Hunyuan3D-2/resolve/main/hunyuan3d-paint-fp16.safetensors" \
  --relative-path models/hunyuan3d2 2>&1 | tail -3 || true

# TRELLIS — Microsoft
log "Downloading TRELLIS weights (~4GB)"
comfy --workspace "$WORKSPACE" model download \
  --url "https://huggingface.co/microsoft/TRELLIS/resolve/main/trellis-image-to-3d.safetensors" \
  --relative-path models/trellis 2>&1 | tail -3 || warn "TRELLIS download failed"

# TripoSR — Stability AI
log "Downloading TripoSR weights (~1.5GB)"
comfy --workspace "$WORKSPACE" model download \
  --url "https://huggingface.co/stabilityai/TripoSR/resolve/main/model.ckpt" \
  --relative-path models/triposr 2>&1 | tail -3 || warn "TripoSR download failed"

# --- 6. Done ---------------------------------------------------------------
log "All set. Open http://127.0.0.1:8188 in your browser to build workflows."
echo
echo "Next steps:"
echo "  1. Export an API-format workflow from the UI → save under workflows/"
echo "  2. python3 scripts/run_3d.py --workflow workflows/<file>.json --prompt '...'"
echo
echo "Health check:  bash scripts/health_check.sh"