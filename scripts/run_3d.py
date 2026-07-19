#!/usr/bin/env python3
"""run_3d.py — submit a ComfyUI 3D-generation workflow with param injection.

Thin wrapper around ComfyUI's /api/prompt endpoint that:
  - injects prompt / seed / steps into the workflow JSON
  - uploads input images for img2mesh workflows
  - polls /api/history until the job finishes
  - downloads all output files (GLB/PLY/STL/PNG) to --output-dir
  - falls back to CPU device on known MPS-incompatible nodes (optional --device)

Usage:
  python3 run_3d.py --workflow workflows/hunyuan3d_2_text2glb.json \
      --prompt "a weathered bronze anchor" --output-dir ../outputs/

  python3 run_3d.py --workflow workflows/trellis_img2glb.json \
      --input-image image=./photo.png --output-dir ../outputs/

  python3 run_3d.py --workflow ... --prompt "..." --count 4 --randomize-seed
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HOST = os.environ.get("COMFY_HOST", "http://127.0.0.1:8188")
TIMEOUT = 1800  # 30 min default for 3D gen (Hunyuan3D-2 can take 10+ min)


def http(method: str, path: str, *, data: bytes | None = None, headers: dict | None = None) -> bytes:
    url = f"{HOST}{path}"
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/json")
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise RuntimeError(f"{method} {path} → HTTP {e.code}: {body[:500]}") from None


def upload_image(local_path: Path, field_name: str = "image") -> str:
    """Upload an image to ComfyUI /api/upload/image, return server-side filename."""
    if not local_path.exists():
        raise FileNotFoundError(local_path)
    # multipart/form-data
    boundary = f"----run3d{os.urandom(8).hex()}"
    with local_path.open("rb") as f:
        file_bytes = f.read()
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{local_path.name}"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode() + file_bytes + b"\r\n"
    body += f"--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n'
    body += f"--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="type"\r\n\r\ninput\r\n'
    body += f"--{boundary}--\r\n".encode()
    resp = http(
        "POST", "/api/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    info = json.loads(resp)
    name = info.get("name") or info.get("filename")
    if not name:
        raise RuntimeError(f"upload response missing name: {info}")
    print(f"  uploaded {local_path.name} → server filename: {name}", file=sys.stderr)
    return name


def load_workflow(path: Path) -> dict:
    wf = json.loads(path.read_text())
    if "nodes" in wf and "links" in wf and "class_type" not in wf:
        raise SystemExit(
            f"{path} is editor-format, not API-format. "
            "Open in ComfyUI UI → Workflow → Export (API)."
        )
    return wf


def inject_params(wf: dict, params: dict) -> dict:
    """Walk the workflow and overwrite matching widget values by name."""
    for node in wf.values():
        if not isinstance(node, dict) or "inputs" not in node:
            continue
        inputs = node["inputs"]
        for key, val in params.items():
            if key in inputs and val is not None:
                inputs[key] = val
    return wf


def find_param_node(wf: dict, key: str) -> str | None:
    """Return node_id of the first node that has a widget named `key`."""
    for nid, node in wf.items():
        if isinstance(node, dict) and key in node.get("inputs", {}):
            return nid
    return None


def submit(wf: dict) -> str:
    payload = json.dumps({"prompt": wf, "client_id": "run_3d"}).encode()
    resp = http("POST", "/api/prompt", data=payload, headers={"Content-Type": "application/json"})
    data = json.loads(resp)
    pid = data.get("prompt_id")
    if not pid:
        raise RuntimeError(f"no prompt_id in response: {data}")
    return pid


def wait_for(pid: str, timeout: int) -> dict:
    deadline = time.time() + timeout
    last_status = None
    while time.time() < deadline:
        # check queue
        q = json.loads(http("GET", "/api/queue"))
        running = q.get("queue_running", [])
        pending = q.get("queue_pending", [])
        if not running and not pending:
            # nothing running — check history
            hist = json.loads(http("GET", f"/api/history/{pid}"))
            if pid in hist:
                return hist[pid]
            # might have just finished between polls
            time.sleep(1)
            hist = json.loads(http("GET", f"/api/history/{pid}"))
            if pid in hist:
                return hist[pid]
            raise RuntimeError(f"prompt {pid} vanished from queue and history")
        status = f"running={len(running)} pending={len(pending)}"
        if status != last_status:
            print(f"  [{pid[:8]}] {status}", file=sys.stderr)
            last_status = status
        time.sleep(3)
    raise TimeoutError(f"prompt {pid} did not finish in {timeout}s")


def download_output(item: dict, out_dir: Path) -> Path:
    fname = item["filename"]
    subfolder = item.get("subfolder", "")
    ftype = item.get("type", "output")
    q = urllib.parse.urlencode({"filename": fname, "subfolder": subfolder, "type": ftype})
    data = http("GET", f"/api/view?{q}")
    dest = out_dir / fname
    dest.write_bytes(data)
    return dest


def collect_outputs(history_entry: dict, out_dir: Path) -> list[Path]:
    outputs_root = history_entry.get("outputs", {})
    results: list[Path] = []
    for _node_id, node_out in outputs_root.items():
        for kind in ("images", "gifs", "meshes", "3d", "videos"):
            for item in node_out.get(kind, []) or []:
                p = download_output(item, out_dir)
                results.append(p)
                print(f"  → {p}", file=sys.stderr)
    return results


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--workflow", required=True, type=Path, help="API-format workflow JSON")
    ap.add_argument("--prompt", help="text prompt (text-to-3D workflows)")
    ap.add_argument("--negative-prompt", help="negative prompt (if workflow supports it)")
    ap.add_argument("--seed", type=int, default=-1, help="-1 = random")
    ap.add_argument("--steps", type=int, help="override sampling steps")
    ap.add_argument("--count", type=int, default=1, help="run N times (batch)")
    ap.add_argument("--randomize-seed", action="store_true", help="new seed per run in batch")
    ap.add_argument("--input-image", action="append", default=[], metavar="KEY=PATH",
                    help="upload image and inject into widget KEY (e.g. image=./photo.png)")
    ap.add_argument("--output-dir", type=Path, default=Path("../outputs"), help="where to save outputs")
    ap.add_argument("--device", choices=["mps", "cpu", "cuda"], help="override device (experimental)")
    ap.add_argument("--timeout", type=int, default=TIMEOUT, help="max seconds to wait per run")
    ap.add_argument("--host", default=HOST, help="ComfyUI base URL")
    args = ap.parse_args()

    global HOST
    HOST = args.host
    args.output_dir.mkdir(parents=True, exist_ok=True)

    wf = load_workflow(args.workflow)
    print(f"Loaded workflow: {args.workflow}", file=sys.stderr)

    # upload input images
    image_params: dict[str, str] = {}
    for spec in args.input_image:
        if "=" not in spec:
            print(f"--input-image must be KEY=PATH, got: {spec}", file=sys.stderr)
            return 2
        key, path = spec.split("=", 1)
        fname = upload_image(Path(path))
        image_params[key] = fname

    all_outputs: list[Path] = []
    for i in range(args.count):
        seed = args.seed
        if args.seed == -1 or (args.count > 1 and args.randomize_seed):
            seed = random.randint(1, 2**31 - 1)

        params: dict = {}
        if args.prompt is not None:
            params["prompt"] = args.prompt
            params["text"] = args.prompt  # some workflows use `text` widget
        if args.negative_prompt is not None:
            params["negative_prompt"] = args.negative_prompt
        if seed is not None:
            params["seed"] = seed
        if args.steps is not None:
            params["steps"] = args.steps
        if args.device:
            params["device"] = args.device
        params.update(image_params)

        run_wf = inject_params(json.loads(json.dumps(wf)), params)
        print(f"\n=== Run {i+1}/{args.count}  seed={seed} ===", file=sys.stderr)
        pid = submit(run_wf)
        print(f"  submitted prompt_id={pid}", file=sys.stderr)
        entry = wait_for(pid, args.timeout)
        outs = collect_outputs(entry, args.output_dir)
        if not outs:
            print(f"  ⚠ no outputs found in history for {pid}", file=sys.stderr)
            print(f"    raw entry: {json.dumps(entry)[:600]}", file=sys.stderr)
        all_outputs.extend(outs)

    print(f"\nDone. {len(all_outputs)} file(s) in {args.output_dir}:")
    for p in all_outputs:
        print(f"  {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())