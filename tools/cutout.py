"""Вырезка фона у фото для первого экрана.

    assets/img/src/hero.jpg → assets/img/src/hero-cutout.png (человек на прозрачном фоне)

Запуск (один раз; на сервер скрипт не попадает — папка tools/ в dist не входит):

    pip install "rembg[cpu]"
    python tools/cutout.py

1. Маска — rembg, модель birefnet-portrait (обучена на портретах: волосы и плечи
   чище, чем у u2net/isnet). Модель rembg скачивает при первом запуске (~1 ГБ).
2. Очистка цвета краёв: в полупрозрачных пикселях (волосы, край пиджака) смешаны
   человек и серый фон студии. Фон под человеком восстанавливается размытием
   «фоновой» части снимка, затем вычитается: F = (I − (1 − α)·B) / α. Без этого
   на зелёном фоне сайта по контуру остался бы серый ореол.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from rembg import new_session, remove

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'assets' / 'img' / 'src' / 'hero.jpg'
OUT = ROOT / 'assets' / 'img' / 'src' / 'hero-cutout.png'


def box(arr, r):
    """Box-размытие по обеим осям через кумулятивные суммы (r — радиус)."""
    for axis in (0, 1):
        pad = [(0, 0)] * arr.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(arr, pad, mode='edge'), axis=axis)
        hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
        lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
        arr = (hi - lo) / (2 * r + 1)
    return arr


def blur(arr, r):
    for _ in range(3):          # три прохода box ≈ гауссово размытие
        arr = box(arr, r)
    return arr


def main():
    image = Image.open(SRC).convert('RGB')
    mask = remove(image, session=new_session('birefnet-portrait'), only_mask=True, post_process_mask=False)

    I = np.asarray(image, dtype=np.float32) / 255
    a = np.asarray(mask.convert('L'), dtype=np.float32)[..., None] / 255

    # фон студии под человеком — нормированная свёртка по пикселям «точно фон»
    bg = (a < 0.02).astype(np.float32)
    B = blur(I * bg, 24) / np.maximum(blur(bg, 24), 1e-4)

    F = np.where(a > 0.02, (I - (1 - a) * B) / np.maximum(a, 0.02), I)
    F = np.where(a >= 0.98, I, np.clip(F, 0, 1))

    rgba = np.concatenate([F, a], axis=-1)
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), mode='RGBA').save(OUT, optimize=True)
    print(f'{OUT.relative_to(ROOT)}: {image.size[0]} x {image.size[1]}')


if __name__ == '__main__':
    main()
