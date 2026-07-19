#!/usr/bin/env bash
# health_check.sh — verify ComfyUI + 3D models/nodes are ready.
set -uo pipefail
GREEN=$'\033[1;32m'; RED=$'\033[1;31m'; NC=$'\033[0m'
ok() { echo "${GREEN}✓${NC} $*"; }
no() { echo "${RED}✗${NC} $*"; }

# comfy-cli installs to ~/.local/bin — ensure it's on PATH for this check
export PATH="$HOME/.local/bin:$PATH"

# auto-discover workspace: try env, then common macOS locations
WORKSPACE=""
for candidate in "${COMFY_WORKSPACE:-}" "$HOME/Documents/comfy" "$HOME/comfy" "$HOME/.comfy"; do
  [ -n "$candidate" ] && [ -d "$candidate/ComfyUI" ] && WORKSPACE="$candidate" && break
done

if command -v comfy >/dev/null 2>&1; then
  ok "comfy-cli: $(comfy --version 2>&1 | head -1)"
else
  no "comfy-cli: not on PATH (run: export PATH=\$HOME/.local/bin:\$PATH)"
fi

if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
  ok "server: http://127.0.0.1:8188"
else
  no "server: not running (run: comfy --workspace \$WORKSPACE launch --background)"
fi

if [ -n "$WORKSPACE" ] && [ -d "$WORKSPACE/ComfyUI" ]; then
  ok "workspace: $WORKSPACE/ComfyUI"
else
  no "workspace: not found (looked in \$COMFY_WORKSPACE, ~/Documents/comfy, ~/comfy)"
fi

echo
echo "Native 3D nodes available (via /object_info):"
if curl -sf http://127.0.0.1:8188/api/object_info >/dev/null 2>&1; then
  curl -s http://127.0.0.1:8188/api/object_info \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
nodes = sorted(n for n in d if any(k in n.lower() for k in ('hunyuan3d','trellis','triposr','triposr','mesh','glb','sf3d')))
if nodes:
    for n in nodes:
        print(f'  {n}')
else:
    print('  (none found — update ComfyUI: comfy --workspace \"'\$WORKSPACE'\" update')
" 2>/dev/null || no "failed to parse /api/object_info"
else
  no "server not reachable — cannot list nodes"
fi

echo
if [ -n "$WORKSPACE" ]; then
  echo "Models on disk (models/):"
  find "$WORKSPACE/ComfyUI/models" -maxdepth 3 -type f \( -name '*.safetensors' -o -name '*.ckpt' -o -name '*.pth' \) 2>/dev/null | head -20 || echo "  (none yet — models auto-download on first workflow run)"
  echo
  echo "HuggingFace cache (auto-downloaded weights):"
  if [ -d "$HOME/.cache/huggingface/hub" ]; then
    du -sh "$HOME/.cache/huggingface/hub" 2>/dev/null
    ls "$HOME/.cache/huggingface/hub" 2>/dev/null | grep -iE 'hunyuan|trellis|tripo' | head -10 || echo "  (no 3D models cached yet)"
  else
    echo "  (no HF cache yet — models download on first Queue run)"
  fi
fi