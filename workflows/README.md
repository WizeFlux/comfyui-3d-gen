# Workflows

ComfyUI хранит workflow JSON в метаданных изображений. Здесь лежат
**официальные example images** от Comfy-Org — в их метаданных зашит
workflow граф Hunyuan3D-2.

## Файлы

| Файл | Что загружает | Тип |
|---|---|---|
| `hunyuan3d_2mv_elf.webp` | Hunyuan3D-2mv multi-view (elf example) | editor-формат в метаданных |
| `hunyuan3d_2mv_turbo.webp` | Hunyuan3D-2mv-turbo (быстрый, 2 views) | editor-формат в метаданных |
| `hunyuan3d_2_single_view.png` | Hunyuan3D-2 single-view (train example) | editor-формат в метаданных |
| `sample_front.png` / `sample_left.png` / `sample_back.png` | входные изображения для multi-view workflow | PNG |

## Как использовать (без Comfy Cloud аккаунта)

ComfyUI Templates → 3D просит cloud-регистрацию, но **drag-and-drop
изображения в canvas работает локально и без аккаунта**:

1. Открой <http://127.0.0.1:8188> в браузере.
2. **Перетащи** один из файлов выше (например `hunyuan3d_2mv_elf.webp`)
   прямо в canvas ComfyUI. Workflow граф загрузится автоматически.
3. (Опционально) Замени `Load Image` ноды на свои изображения —
   перетащи свои PNG в canvas или используй существующие `sample_*.png`.
4. Нажми **Queue** (Cmd+Enter). При первом запуске ComfyUI скачает
   веса Hunyuan3D-DiT-v2-0 (~14GB) + Hunyuan3D-Paint-v2-0 (~5GB) в
   `~/.cache/huggingface/hub`. Следи за панелью ☐ справа сверху.
5. Выход: `~/comfy/output/mesh/*.glb`

## Чтобы запустить через `run_3d.py` (из CLI)

`run_3d.py` принимает только **API-формат** JSON (где каждый node
имеет `class_type`), а в картинках лежит **editor-формат**
(`nodes` + `links` массивы). Конвертация:

1. Открой картинку в ComfyUI UI (drag-drop в canvas).
2. Меню: **Workflow → Export (API)** (новый UI) или
   **Save (API Format)** (старый UI).
3. Сохрани как `workflows/hunyuan3d_2_img2glb.json`.
4. Запуск:
   ```bash
   python3 scripts/run_3d.py \
     --workflow workflows/hunyuan3d_2_img2glb.json \
     --input-image image=./workflows/sample_front.png \
     --output-dir outputs/
   ```

`run_3d.py` сам определит editor-формат и подскажет переэкспортировать,
если подсунешь не API-формат.