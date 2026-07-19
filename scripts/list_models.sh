#!/usr/bin/env bash
# list_models.sh — list all installed ComfyUI models.
set -euo pipefail
WORKSPACE="${COMFY_WORKSPACE:-$HOME/comfy}"
comfy --workspace "$WORKSPACE" model list