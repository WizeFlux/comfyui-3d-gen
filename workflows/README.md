# Workflows

Сюда складываем ComfyUI workflow JSON в **API-формате** (не editor-формат).

## Как получить API-format JSON

1. Открой ComfyUI: <http://127.0.0.1:8188>
2. Загрузи или собери граф (например, Hunyuan3D-2 или TRELLIS).
3. Меню: **Workflow → Export (API)** (в новых версиях UI).
   В старых: кнопка **Save (API Format)**.
4. Сохрани файл сюда как `hunyuan3d_2_text2glb.json` и т.п.

## Имена файлов (соглашение)

| Файл | Что делает |
|---|---|
| `hunyuan3d_2_text2glb.json` | Hunyuan3D-2: текст → GLB+текстуры |
| `hunyuan3d_2_img2glb.json`  | Hunyuan3D-2: изображение → GLB |
| `trellis_img2glb.json`      | TRELLIS: изображение → GLB |
| `triposr_img2glb.json`      | TripoSR: изображение → GLB (быстро) |

## Проверка формата

Скрипт `run_3d.py` сам определит, если файл в editor-формате (есть `nodes`/`links`, но нет `class_type`), и подскажет переэкспортировать.