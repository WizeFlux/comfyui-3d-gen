# comfyui-3d-gen

ComfyUI workflows для генерации 3D-моделей (text-to-3D, image-to-3D) на macOS Apple Silicon.

Таргет: **Mac M1 Ultra 128GB** (MPS backend). Поддерживаемые модели:

| Модель | Тип | VRAM | Выход |
|---|---|---|---|
| **Hunyuan3D-2** (Tencent) | text/image → 3D | ~16GB | GLB + текстуры |
| **TRELLIS** (Microsoft) | image → 3D | ~12GB | GLB/SLAT |
| **TripoSR** (Stability) | image → 3D | ~8GB | GLB (быстро, грубее) |

## Структура

```
comfyui-3d-gen/
├── scripts/
│   ├── bootstrap_macos.sh   # установка comfy-cli + ComfyUI + модели
│   ├── run_3d.py            # запуск workflow (text2mesh / img2mesh)
│   ├── list_models.sh       # список установленных моделей
│   └── health_check.sh      # проверка сервера и моделей
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
1. Ставит `comfy-cli` через `pipx` (или `uvx`).
2. Инсталлирует ComfyUI с `--m-series` (MPS).
3. Запускает сервер в фоне на `:8188`.
4. Качает Hunyuan3D-2 + TRELLIS + TripoSR веса.
5. Ставит кастомные ноды: `ComfyUI-3D-Pack`, `ComfyUI-Hunyuan3D-2`, `ComfyUI-TRELLIS`.

## Запуск

### text → 3D (Hunyuan3D-2)

```bash
python3 scripts/run_3d.py \
  --workflow workflows/hunyuan3d_2_text2glb.json \
  --prompt "a weathered bronze anchor, detailed, pbr" \
  --output-dir outputs/
```

### image → 3D

```bash
python3 scripts/run_3d.py \
  --workflow workflows/trellis_img2glb.json \
  --input-image ./my_photo.png \
  --output-dir outputs/
```

### Случайные сиды (вариации)

```bash
python3 scripts/run_3d.py --workflow ... --prompt "..." --count 4 --randomize-seed
```

## Получение workflow JSON

Workflow'ы в API-формате нужно экспортировать из ComfyUI web UI:

1. Открой `http://localhost:8188` в браузере.
2. Загрузи пример графа из `workflows/` или собери свой.
3. **Workflow → Export (API)** → сохрани в `workflows/`.
4. Имя в `--workflow` — путь к этому JSON.

Парочку готовых workflow'ов положу в `workflows/` после первого запуска.

## Проверка

```bash
bash scripts/health_check.sh
```

Должно вывести: `comfy-cli: ok`, `server: ok`, `models: N installed`.

## Замечания по M1 Ultra

- MPS поддерживается, но не все ноды оптимизированы — некоторые 3D-ноды могут падать на `aten::grid_sample` на MPS. В ранере есть `--device cpu` фолбэк.
- 128GB unified memory — хватит на все три модели без swapping.
- Первый запуск Hunyuan3D-2: ~6–10 минут на меш. TripoSR: ~30–60 сек.