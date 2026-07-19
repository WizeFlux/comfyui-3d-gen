# Workflows

ComfyUI workflows для генерации 3D-моделей.

## Text-to-3D (текст → 3D-модель) ⭐

Двухступенчатый пайплайн: **SD3.5 генерит multi-view изображения из текста → Hunyuan3D-2mv собирает из них 3D-меш с текстурами**.

| Файл | Описание |
|---|---|
| `text_to_3d_improved_alignment.json` | ⭐ Рекомендуемый. Multi-view с улучшенным выравниванием. |
| `text_to_3d_hd_single_prompt.json` | High-Definition, single prompt (один промпт → все views). |

**Что нужно:** модель Stable Diffusion 3.5 (скачается автоматически при первом запуске, или укажи свою через `CheckpointLoaderSimple`).

## Image-to-3D (изображение → 3D-модель)

Hunyuan3D-2 нативный, workflow зашит в метаданных изображений:

| Файл | Что загружает |
|---|---|
| `hunyuan3d_2mv_elf.webp` | Hunyuan3D-2mv multi-view (elf example, 3 views) |
| `hunyuan3d_2mv_turbo.webp` | Hunyuan3D-2mv-turbo (быстрый, 2 views) |
| `hunyuan3d_2_single_view.png` | Hunyuan3D-2 single-view (train example) |
| `sample_front.png` / `sample_left.png` / `sample_back.png` | входные изображения для multi-view |

## Как использовать (без Comfy Cloud аккаунта)

### Text-to-3D

1. Открой <http://127.0.0.1:8188> в браузере.
2. Меню: **Workflow → Open (Ctrl+O)** → выбери `text_to_3d_improved_alignment.json`.
   - Или просто перетащи JSON-файл в canvas.
3. Найди ноду `PrimitiveStringMultiline` — там твой текстовый промпт.
   Измени текст на то, что хочешь сгенерировать.
4. Нажми **Queue** (Cmd+Enter).
5. При первом запуске скачаются:
   - SD3.5 модель (~6-12GB)
   - Hunyuan3D-DiT-v2-0 (~14GB) + Hunyuan3D-Paint-v2-0 (~5GB)
6. Выход: `~/comfy/output/mesh/*.glb`

### Image-to-3D (drag-and-drop)

1. Перетащи `hunyuan3d_2mv_elf.webp` в canvas — workflow загрузится из метаданных.
2. (Опционально) замени `Load Image` ноды на свои изображения.
3. **Queue** → выход в `~/comfy/output/mesh/*.glb`.

## Запуск через `run_3d.py` (из CLI)

`run_3d.py` принимает только **API-формат** JSON. Все workflow выше — editor-формат. Конвертация:

1. Открой workflow в ComfyUI UI (drag-and-drop или Ctrl+O).
2. Меню: **Workflow → Export (API)** (новый UI) или **Save (API Format)** (старый UI).
3. Сохрани как `workflows/text_to_3d.json` (или `hunyuan3d_2_img2glb.json`).
4. Запуск:
   ```bash
   python3 scripts/run_3d.py \
     --workflow workflows/text_to_3d.json \
     --prompt "a weathered bronze anchor, detailed pbr" \
     --output-dir outputs/
   ```

`run_3d.py` сам определит editor-формат и подскажет переэкспортировать.