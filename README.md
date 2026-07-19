# comfyui-3d-gen

ComfyUI workflows для генерации 3D-моделей (text-to-3D, image-to-3D) на macOS Apple Silicon.

Таргет: **Mac M1 Ultra 128GB** (MPS backend).

> **Важно:** Hunyuan3D-2 теперь **встроен в ComfyUI нативно** — кастомные ноды и ручная загрузка весов не нужны. Workflow'ы доступны через **Templates → 3D** в UI, а loader-ноды сами скачивают веса с HuggingFace при первом запуске.

| Модель | Тип | Где взять |
|---|---|---|
| **Hunyuan3D-DiT-v2-0** | image → shape (geometry) | Templates → 3D → Hunyuan3D-2 |
| **Hunyuan3D-Paint-v2-0** | shape → textured GLB | (часть того же workflow) |
| **Hunyuan3D-2mv** | multi-view → shape | Templates → 3D → Hunyuan3D-2mv |
| **Hunyuan3D-2mv-turbo** | multi-view → shape (быстрый) | Templates → 3D → Hunyuan3D-2mv-turbo |
| **TripoSR** | image → GLB (быстро, грубее) | community custom node |

## Структура

```
comfyui-3d-gen/
├── scripts/
│   ├── bootstrap_macos.sh   # установка comfy-cli + ComfyUI (нативные 3D ноды уже внутри)
│   ├── run_3d.py            # запуск API-format workflow (text/img → mesh) из CLI
│   ├── list_models.sh       # список установленных моделей
│   └── health_check.sh      # проверка сервера, нод, моделей, HF-кэша
├── workflows/               # API-format JSON (экспорт из ComfyUI UI)
└── outputs/                 # сюда падают GLB/PLY (gitignored)
```

## Установка на Mac (один раз)

```bash
git clone https://github.com/WizeFlux/comfyui-3d-gen.git
cd comfyui-3d-gen
bash scripts/bootstrap_macos.sh
```

Скрипт:
1. Ставит `uv` + `comfy-cli` (Python 3.12, чтобы обойти pyo3-ffi на 3.14).
2. Инсталлирует ComfyUI с `--m-series` (MPS) в `~/Documents/comfy/`.
3. Запускает сервер в фоне на `:8188`.
4. Ставит `comfyui-essentials` (препроцессинг изображений для img2mesh).
5. **Весы моделей не качает** — ComfyUI сам скачает при первом запуске workflow.

## Получение workflow JSON

1. Открой <http://127.0.0.1:8188> в браузере.
2. **Templates → 3D** → выбери Hunyuan3D-2 (или 2mv, 2mv-turbo).
   - Альтернатива: перетащи пример-картинку с <https://docs.comfy.org/tutorials/3d/hunyuan3D-2> в canvas — workflow загрузится автоматически.
3. Нажми **Queue** (Cmd+Enter). При первом запуске ComfyUI скачает веса Hunyuan3D-DiT-v2-0 (~14GB) и Hunyuan3D-Paint-v2-0 (~5GB) в `~/.cache/huggingface/hub`. Следи за панелью ☐ в правом верхнем углу.
4. После успешного запуска: **Workflow → Export (API)** → сохрани в `workflows/hunyuan3d_2_img2glb.json`.

## Запуск из CLI

### image → 3D (Hunyuan3D-2)

```bash
python3 scripts/run_3d.py \
  --workflow workflows/hunyuan3d_2_img2glb.json \
  --input-image image=./my_photo.png \
  --output-dir outputs/
```

### text → 3D (если в workflow есть text prompt widget)

```bash
python3 scripts/run_3d.py \
  --workflow workflows/hunyuan3d_2_text2glb.json \
  --prompt "a weathered bronze anchor, detailed pbr" \
  --output-dir outputs/
```

### Вариации (несколько сидов)

```bash
python3 scripts/run_3d.py --workflow ... --prompt "..." --count 4 --randomize-seed
```

## Проверка

```bash
bash scripts/health_check.sh
```

Должно показать: `comfy-cli: ok`, `server: ok`, `workspace: ok`, и список нативных 3D-нод (`Hunyuan3Dv2*`, и т.д.).

## Замечания по M1 Ultra

- **MPS**: поддерживается, но отдельные ops (особенно `aten::grid_sample` в TRELLIS) могут падать. В `run_3d.py` есть `--device cpu` фолбэк.
- **128GB unified memory** — хватит на все модели Hunyuan3D-2 (полный пайплайн требует ~12GB VRAM).
- **Первый запуск** Hunyuan3D-2: ~10–15 минут (скачивание весов) + ~5–10 минут на меш. Последующие: ~5–10 мин на меш.
- **Выход**: `$WORKSPACE/ComfyUI/output/mesh/*.glb` (при запуске через UI) или `outputs/` (при запуске через `run_3d.py`).