#!/usr/bin/env bash
# health_check.sh — verify ComfyUI + 3D nodes/models are ready.
set -uo pipefail
GREEN=$'\033[1;32m'; RED=$'\033[1;31m'; NC=$'\033[0m'
ok() { echo "${GREEN}✓${NC} $*"; }
no() { echo "${RED}✗${NC} $*"; }

# comfy-cli installs to ~/.local/bin — ensure it's on PATH for this check
export PATH="$HOME/.local/bin:$PATH"

# is_comfyui_root <dir>: ComfyUI root has main.py + comfy/ package dir
is_comfyui_root() {
  [ -f "$1/main.py" ] && [ -d "$1/comfy" ]
}

# auto-discover workspace: try env, then common macOS locations.
# comfy-cli on macOS installs flat (~/comfy IS the ComfyUI root, not ~/comfy/ComfyUI).
COMFY_ROOT=""
for candidate in "${COMFY_WORKSPACE:-}" "$HOME/Documents/comfy" "$HOME/comfy" "$HOME/.comfy" "$HOME/Documents/comfy/ComfyUI" "$HOME/comfy/ComfyUI"; do
  [ -n "$candidate" ] || continue
  if is_comfyui_root "$candidate"; then
    COMFY_ROOT="$candidate"
    break
  fi
done

if command -v comfy >/dev/null 2>&1; then
  ok "comfy-cli: $(comfy --version 2>&1 | head -1)"
else
  no "comfy-cli: not on PATH (run: export PATH=\$HOME/.local/bin:\$PATH)"
fi

if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
  ok "server: http://127.0.0.1:8188"
else
  no "server: not running (run: comfy launch --background)"
fi

if [ -n "$COMFY_ROOT" ]; then
  ok "workspace: $COMFY_ROOT"
else
  no "workspace: not found (looked for main.py+comfy/ in \$COMFY_WORKSPACE, ~/Documents/comfy, ~/comfy)"
fi

echo
echo "Native 3D nodes available (via /object_info):"
if curl -sf http://127.0.0.1:8188/api/object_info >/dev/null 2>&1; then
  curl -s http://127.0.0.1:8188/api/object_info > /tmp/comfy_obj_info.json
  python3 - <<'PY' </tmp/comfy_obj_info.json
import sys, json
try:
    d = json.load(sys.stdin)
except Exception as e:
    print(f"  (parse error: {e})")
    sys.exit(0)
keys = ("hunyuan3d", "trellis", "triposr", "triposplat", "sf3d", "mesh", "glb")
nodes = sorted(n for n in d if any(k in n.lower() for k in keys))
if nodes:
    for n in nodes:
        print(f"  {n}")
else:
    print("  (no 3D nodes found — update ComfyUI to latest nightly)")
PY
  rm -f /tmp/comfy_obj_info.json
else
  no "server not reachable — cannot list nodes"
fi

echo
if [ -n "$COMFY_ROOT" ]; then
  echo "Models on disk ($COMFY_ROOT/models):"
  find "$COMFY_ROOT/models" -maxdepth 3 -type f \( -name '*.safetensors' -o -name '*.ckpt' -o -name '*.pth' \) 2>/dev/null | head -20
  echo
  echo "HuggingFace cache (auto-downloaded weights):"
  if [ -d "$HOME/.cache/huggingface/hub" ]; then
    du -sh "$HOME/.cache/huggingface/hub" 2>/dev/null
    ls "$HOME/.cache/huggingface/hub" 2>/dev/null | grep -iE 'hunyuan|trellis|tripo' | head -10 || echo "  (no 3D models cached yet — they download on first Queue run)"
  else
    echo "  (no HF cache yet — models download on first Queue run)"
  fi
  echo
  echo "Output dir ($COMFY_ROOT/output):"
  ls -la "$COMFY_ROOT/output" 2>/dev/null | head -10
fi