#!/usr/bin/env bash
# bootstrap_macos.sh — install ComfyUI on Apple Silicon Mac for 3D generation.
# Target: M1 Ultra 128GB (MPS). Tested on macOS 14+.
#
# NOTE: Hunyuan3D-2 is now BUILT INTO ComfyUI natively (find it in Templates → 3D).
# No custom nodes or manual model downloads required — ComfyUI's loader nodes
# auto-download from HuggingFace on first run.
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
# pydantic-core (dep of comfy-cli) uses pyo3-ffi, which lags Python releases.
# Python 3.14+ breaks pyo3-ffi <0.25. Pin to 3.12 via uv (preferred) or brew.
NEED_PY="3.12"

have_comfy() { command -v comfy >/dev/null 2>&1; }

if ! have_comfy; then
  if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv"
    brew install uv
  fi
  log "Installing comfy-cli via uv (pinned to Python $NEED_PY)"
  uv tool install --python "$NEED_PY" comfy-cli
  export PATH="$HOME/.local/bin:$PATH"
  grep -q '.local/bin' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
fi

comfy --skip-prompt tracking disable >/dev/null 2>&1 || true

# --- 2. ComfyUI install (M-series / MPS) -----------------------------------
# comfy-cli on macOS defaults to ~/Documents/comfy/ComfyUI
WORKSPACE="${COMFY_WORKSPACE:-$HOME/Documents/comfy}"
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

# --- 4. Helper nodes (optional) --------------------------------------------
# Hunyuan3D-2 / TRELLIS core nodes ship with ComfyUI itself now.
# comfyui-essentials adds background-removal and image helpers useful for img2mesh.
log "Installing comfyui-essentials (image preprocessing helpers)"
comfy --workspace "$WORKSPACE" node install comfyui-essentials 2>&1 | tail -2 || warn "essentials install failed (non-critical)"

# --- 5. Done ---------------------------------------------------------------
log "All set."
echo
echo "  ➜ Open http://127.0.0.1:8188 in your browser."
echo "  ➜ In the UI: Templates → 3D → Hunyuan3D-2 (or Hunyuan3D-2mv, Hunyuan3D-2mv-turbo)."
echo "  ➜ Drag one of the example workflow images from"
echo "    https://docs.comfy.org/tutorials/3d/hunyuan3D-2 into the canvas to load it."
echo "  ➜ On first Queue run, ComfyUI auto-downloads the model weights (~14GB for"
echo "    Hunyuan3D-DiT-v2-0, ~5GB for Paint). Watch the panel ☐ in the top-right."
echo "  ➜ Outputs land in $WORKSPACE/ComfyUI/output/mesh/*.glb"
echo
echo "  Health check:  bash scripts/health_check.sh"