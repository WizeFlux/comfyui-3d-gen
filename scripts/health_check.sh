#!/usr/bin/env bash
# health_check.sh — verify ComfyUI + 3D models are ready.
set -uo pipefail
GREEN=$'\033[1;32m'; RED=$'\033[1;31m'; NC=$'\033[0m'
ok() { echo "${GREEN}✓${NC} $*"; }
no() { echo "${RED}✗${NC} $*"; }

WORKSPACE="${COMFY_WORKSPACE:-$HOME/comfy}"

if command -v comfy >/dev/null 2>&1; then
  ok "comfy-cli: $(comfy --version 2>&1 | head -1)"
else
  no "comfy-cli: not on PATH (run: export PATH=\$HOME/.local/bin:\$PATH)"
fi

if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
  ok "server: http://127.0.0.1:8188"
else
  no "server: not running (run: comfy --workspace $WORKSPACE launch --background)"
fi

if [ -d "$WORKSPACE/ComfyUI" ]; then
  ok "workspace: $WORKSPACE/ComfyUI"
else
  no "workspace: $WORKSPACE/ComfyUI not found"
fi

echo
echo "Installed models:"
comfy --workspace "$WORKSPACE" model list 2>/dev/null | head -40 || no "could not list models"

echo
echo "Installed nodes:"
comfy --workspace "$WORKSPACE" node show installed 2>/dev/null | grep -iE "hunyuan|trellis|tripo|3d" || echo "  (no 3D nodes found — run bootstrap_macos.sh)"