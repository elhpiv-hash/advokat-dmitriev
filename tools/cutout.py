"""Вырезка фона у фото для первого экрана.

    assets/img/src/hero-new.jpg → assets/img/src/hero-cutout.png (человек на прозрачном фоне)

Запуск (один раз; на сервер скрипт не попадает — папка tools/ в dist не входит):

    pip install "rembg[cpu]"
    python tools/cutout.py

1. Маска — rembg, модель birefnet-portrait (обучена на портретах: волосы и плечи
   чище, чем у u2net/isnet). Модель rembg скачивает при первом запуске (~1 ГБ).
2. Очистка цвета краёв: в полупрозрачных пикселях (волосы, борода, оправа очков)
   смешаны человек и фон снимка (небо, ели). Фон под человеком восстанавливается
   размытием «фоновой» части снимка, затем вычитается: F = (I − (1 − α)·B) / α.
   Без этого на зелёном фоне сайта по контуру остался бы светлый ореол неба
   и зелень ёлок.
3. Контур 3 px получает цвет изнутри фигуры (как «Defringe» в Photoshop):
   там, где фон пёстрый (ветки на небе), вычитание из п. 2 неточно, и между
   прядями оставались бы светлые просветы.
4. Пустое небо над головой срезается (поле 3 % высоты), а там, где тело
   упирается в край кадра (плечи по бокам, грудь снизу), прозрачность плавно
   растёт к краю: без рамки срез кадра читался бы как прямая линия.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from rembg import new_session, remove

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'assets' / 'img' / 'src' / 'hero-new.jpg'
OUT = ROOT / 'assets' / 'img' / 'src' / 'hero-cutout.png'
PLATE = (0x22, 0x66, 0x5B)      # фон первого экрана (--p-plate в css/style.css)


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


def erode(mask, r):
    """Сужение маски на r px: пиксель остаётся, если весь квадрат вокруг — маска."""
    return box(mask.astype(np.float32), r) > 0.999


def main():
    image = Image.open(SRC).convert('RGB')
    mask = remove(image, session=new_session('birefnet-portrait'), only_mask=True, post_process_mask=False)

    I = np.asarray(image, dtype=np.float32) / 255
    a = np.asarray(mask.convert('L'), dtype=np.float32)[..., None] / 255

    # фон под человеком — нормированная свёртка по пикселям «точно фон»
    bg = (a < 0.02).astype(np.float32)
    B = blur(I * bg, 24) / np.maximum(blur(bg, 24), 1e-4)

    F = np.where(a > 0.02, (I - (1 - a) * B) / np.maximum(a, 0.02), I)
    F = np.where(a >= 0.98, I, np.clip(F, 0, 1))

    # контур: цвет из «точно фигуры» в 3 px глубже — нормированная свёртка
    solid = a[..., 0] >= 0.98
    inner = erode(solid, 3).astype(np.float32)[..., None]
    edge = (a[..., 0] > 0.02) & ~erode(solid, 3)
    G = blur(F * inner, 3) / np.maximum(blur(inner, 3), 1e-4)
    known = blur(inner, 3) > 1e-3
    F = np.where((edge & known[..., 0])[..., None], G, F)

    # пустое небо над головой — прочь, с полем 3 % высоты
    rows = np.nonzero((a[..., 0] > 0.5).any(axis=1))[0]
    top = max(0, rows[0] - round(0.03 * a.shape[0]))
    F, a = F[top:], a[top:]
    h, w = a.shape[:2]

    # растушёвка там, где тело упирается в край кадра: бока — 12 % ширины,
    # низ — 26 % высоты (smoothstep — без заметной границы начала)
    def ramp(n, size):
        t = np.clip(np.arange(n) / size, 0, 1)
        return t * t * (3 - 2 * t)
    fx = np.minimum(ramp(w, 0.12 * w), ramp(w, 0.12 * w)[::-1])
    fy = ramp(h, 0.26 * h)[::-1]
    a = a * (fy[:, None] * fx[None, :])[..., None]

    # Полностью прозрачные пиксели не видны, но их цвет кодируется: ели и небо
    # там утяжеляли бы AVIF в несколько раз. Заливаем ровным зелёным фона сайта.
    F = np.where(a * 255 < 0.5, np.array(PLATE, dtype=np.float32) / 255, F)

    rgba = np.concatenate([F, a], axis=-1)
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), mode='RGBA').save(OUT, optimize=True)
    print(f'{OUT.relative_to(ROOT)}: {w} x {h} (срезано сверху {top} px)')


if __name__ == '__main__':
    main()
