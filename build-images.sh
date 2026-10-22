#!/usr/bin/env bash
# ==========================================================================
#  build-images.sh — фото, og-cover, favicon и apple-touch-icon
#  --------------------------------------------------------------------------
#  1. Два снимка (исходники в assets/img/src/, подойдут .jpg .jpeg .png .webp):
#     hero.jpg  — первый экран, фото в полный рост, кадр 2 : 3 →
#                 assets/img/hero-480|852.avif|webp, hero-800.jpg
#                 Пока его нет, в первом экране — заглушка (портрет из about.jpg
#                 туда не ставим: он уже есть в «Об адвокате»).
#     about.jpg — портрет за столом в «Об адвокате», кадр 10 : 13 →
#                 assets/img/about-480|800|978.avif|webp, about-800.jpg
#     Пропорции кадров совпадают с исходниками (852 × 1280, 978 × 1280):
#     снимок почти не обрезается — лицо и руки целиком. Если пропорции нового
#     исходника другие, лишнее срезается по «интересной» области (лицу).
#     Самая крупная ширина — ширина исходника: увеличивать снимок незачем.
#     Если нет и исходника — те же файлы рисуются как аккуратная заглушка:
#     монограмма «ДА» в двойной рамке на ПРОЗРАЧНОМ фоне (AVIF/WebP) —
#     фон даёт CSS (--p-plate), поэтому заглушка подходит к любой палитре.
#     Заменить фото = положить файл в assets/img/src/ и запустить скрипт;
#     index.html трогать не нужно — пути у фото и заглушки одинаковые.
#  2. assets/img/og-cover.jpg (1200 × 630) — превью ссылки в мессенджерах:
#     имя, направления, телефон и портрет из about.jpg (или заглушка). Текст переводится
#     в контуры прямо из woff2 Geologica — браузер и системные шрифты не нужны.
#  3. assets/img/favicon.svg, favicon.ico (16, 32, 48 px) и
#     apple-touch-icon.png (180 px, для «На экран „Домой“» в iOS).
#
#  Цвета og-cover, favicon и фона JPG — палитры сайта «Зимний дворец»
#  (те же, что --p-plate и --d-* в css/style.css).
#
#  Запуск:   bash build-images.sh
#  Нужен Node.js 18+. sharp, fontkit и wawoff2 ставятся во временную папку
#  при каждом запуске (npm берёт их из кэша) — в проекте нет package.json
#  и node_modules, как и у build.sh.
#
#  Метаданные фото (EXIF с геометкой и моделью телефона) удаляются: sharp
#  не переносит их без явного запроса. Поворот по EXIF применяется к пикселям
#  до удаления — снимок с телефона не ляжет набок.
# ==========================================================================

set -euo pipefail

# Работаем из папки скрипта: пути не зависят от того, откуда его запустили.
cd "$(dirname "$0")"

if ! command -v npm >/dev/null 2>&1; then
  echo "Ошибка: не найден npm. Установите Node.js 18+ (https://nodejs.org)." >&2
  exit 1
fi

# Временная папка под зависимости и сам скрипт; удаляется при любом выходе.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ sharp, fontkit, wawoff2: установка во временную папку"
# Версии зафиксированы: сборка воспроизводима.
npm install --prefix "$TMP" --no-save --no-audit --no-fund --loglevel=error \
  sharp@0.34 fontkit@2 wawoff2@2 >/dev/null

cat > "$TMP/build-images.cjs" <<'NODE'
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const fontkit = require('fontkit');
const wawoff2 = require('wawoff2');

const IMG = 'assets/img';
const SRC = path.join(IMG, 'src');
const FONTS = 'assets/fonts';

// Цвета тёмной схемы — те же, что --p-plate и --d-* в css/style.css
const C = { plate: '#22665B', fg: '#FFFFFF', strong: '#F0F6F3', muted: '#DDECE7', accent: '#E3B85F', accentText: '#F8E0A8' };

// Монограмма «ДА» — те же контуры Geologica 600, что в спрайте index.html (viewBox 48)
// и, крупнее, в favicon (viewBox 64)
const MONO = 'M18.94 30.5L18.94 20.02L14.6 20.02L14.6 21.28Q14.6 23.55 14.36 25.17Q14.13 26.8 13.63 27.86Q13.12 28.93 12.28 29.55Q11.45 30.18 10.25 30.46L9.29 28.17Q10.11 27.98 10.64 27.6Q11.16 27.22 11.46 26.47Q11.76 25.73 11.87 24.47Q11.99 23.21 11.99 21.28L11.99 17.5L21.69 17.5L21.69 30.5ZM9.29 33.79L9.29 28.17L10.94 28.24L11.84 27.98L23.78 27.98L23.78 33.79L21.17 33.79L21.17 30.5L11.9 30.5L11.9 33.79ZM25.66 30.5L30.58 17.5L33.71 17.5L38.71 30.5L35.61 30.5L34.6 27.71L29.65 27.71L28.67 30.5ZM30.3 25.39L33.93 25.39L32.09 20.52Z';

const MONO_64 = 'M25.06 40.75L25.06 26.71L19.33 26.71L19.33 28.33Q19.33 31.38 19.01 33.56Q18.69 35.74 18 37.18Q17.31 38.63 16.18 39.47Q15.05 40.31 13.41 40.7L12.11 37.54Q13.21 37.29 13.91 36.78Q14.61 36.26 15.01 35.27Q15.41 34.28 15.57 32.59Q15.73 30.91 15.73 28.33L15.73 23.25L28.85 23.25L28.85 40.75ZM12.11 45.16L12.11 37.54L14.34 37.63L15.58 37.29L31.68 37.29L31.68 45.16L28.08 45.16L28.08 40.75L15.7 40.75L15.7 45.16ZM34.24 40.75L40.85 23.25L45.19 23.25L51.89 40.75L47.61 40.75L46.27 37.04L39.69 37.04L38.39 40.75ZM40.57 33.85L45.36 33.85L42.95 27.39Z';

const kb = (file) => (fs.statSync(file).size / 1024).toFixed(1).padStart(8);
const log = (file, w, h) => console.log(`  ${path.basename(file).padEnd(20)} ${String(w).padStart(5)} x ${String(h).padEnd(5)} ${kb(file)} KB`);

/* ----- Портрет ----- */

// Первый найденный исходник из списка имён
function findSource(names) {
  for (const name of names) {
    for (const ext of ['jpg', 'jpeg', 'png', 'webp']) {
      const file = path.join(SRC, `${name}.${ext}`);
      if (fs.existsSync(file)) return file;
    }
  }
  return null;
}

// Наборы файлов. ratio = высота / ширина — как у исходников; те же пропорции
// заданы в CSS (aspect-ratio) и в width/height у <img> в index.html.
const SETS = {
  hero: { sources: ['hero'], widths: [480, 852], ratio: 1.5 },
  about: { sources: ['about'], widths: [480, 800, 978], ratio: 1.3 }
};

// Заглушка 4 : 5: монограмма в тонкой двойной рамке на прозрачном фоне —
// фон и цвет подложки даёт CSS, поэтому заглушка подходит к любой палитре.
// Линии и буквы белые полупрозрачные: на тёмной подложке любого варианта.
// Толщина линий — в пикселях, а не масштабом знака из спрайта: при увеличении
// в 9 раз рамка 1.25 / 0.75 стала бы тяжёлой.
function placeholderSvg(w, h) {
  const s = w / 1200;
  const mono = 9 * s;                    // масштаб монограммы: буквы ≈ 117 px на 1200
  const cx = w / 2, cy = h * 0.47;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs><radialGradient id="g" cx="50%" cy="38%" r="70%">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.07"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient></defs>
  <rect width="${w}" height="${h}" fill="url(#g)"/>
  <rect x="${cx - 24 * mono}" y="${cy - 24 * mono}" width="${48 * mono}" height="${48 * mono}" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="${Math.max(1, 3 * s)}"/>
  <rect x="${cx - 19.5 * mono}" y="${cy - 19.5 * mono}" width="${39 * mono}" height="${39 * mono}" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="${Math.max(1, 1.5 * s)}"/>
  <path transform="translate(${cx - 24 * mono} ${cy - 24 * mono}) scale(${mono})" fill="#FFFFFF" fill-opacity="0.88" d="${MONO}"/>
</svg>`;
}

async function buildSet(name) {
  const { sources, widths, ratio } = SETS[name];
  const file = findSource(sources);
  const height = (w) => Math.round(w * ratio);
  let make;

  if (file) {
    console.log(`→ ${name}: ${file}`);
    const meta = await sharp(file).rotate().metadata();
    const need = widths[widths.length - 1];
    if (Math.min(meta.width / need, meta.height / height(need)) < 1) {
      console.log(`  ! исходник мал (${meta.width} x ${meta.height}): для резкости нужен от ${need} x ${height(need)}`);
    }
    // attention — кадр по самой «интересной» области (лицо), а не по центру
    make = (w) => sharp(file).rotate().resize(w, height(w), { fit: 'cover', position: 'attention' });
  } else {
    console.log(`→ ${name}: исходника нет — заглушка с монограммой (прозрачный фон)`);
    make = (w) => sharp(Buffer.from(placeholderSvg(w, height(w))));
  }

  for (const w of widths) {
    const avif = path.join(IMG, `${name}-${w}.avif`);
    await make(w).avif({ quality: 55, effort: 6 }).toFile(avif);
    log(avif, w, height(w));
    const webp = path.join(IMG, `${name}-${w}.webp`);
    await make(w).webp({ quality: 80, effort: 6 }).toFile(webp);
    log(webp, w, height(w));
  }
  const jpg = path.join(IMG, `${name}-800.jpg`);
  // mozjpeg + прогрессивная развёртка: меньше вес, снимок проявляется целиком сразу;
  // у JPG прозрачности нет — фон заглушки цвета подложки (--p-plate)
  await make(800).flatten({ background: C.plate }).jpeg({ quality: 82, mozjpeg: true, progressive: true }).toFile(jpg);
  log(jpg, 800, height(800));

  return make;
}

/* ----- Текст → контуры (Geologica из woff2) ----- */

async function loadFonts() {
  const files = ['geologica-cyrillic', 'geologica-latin', 'geologica-latin-ext', 'geologica-cyrillic-ext'];
  const fonts = [];
  for (const name of files) {
    const ttf = Buffer.from(await wawoff2.decompress(fs.readFileSync(path.join(FONTS, `${name}.woff2`))));
    fonts.push(fontkit.create(ttf));
  }
  return fonts;
}

// Строка в SVG-контур: для каждого знака — первое подмножество шрифта, где он есть.
// Кернинг не применяется — на превью 1200 px разница не видна.
function textPath(fonts, str, { size, weight, x, y, fill, tracking = 0 }) {
  const cache = new Map();
  const variant = (font) => {
    if (!cache.has(font)) cache.set(font, font.getVariation({ wght: weight }));
    return cache.get(font);
  };
  let pen = x;
  let d = '';
  for (const ch of str) {
    const cp = ch.codePointAt(0);
    const font = fonts.find((f) => f.hasGlyphForCodePoint(cp)) || fonts[0];
    const glyph = variant(font).getGlyph(font.glyphForCodePoint(cp).id);
    const scale = size / font.unitsPerEm;
    d += glyph.path.scale(scale, -scale).translate(pen, y).toSVG();
    pen += glyph.advanceWidth * scale + tracking;
  }
  return { svg: `<path fill="${fill}" d="${d}"/>`, width: pen - x };
}

/* ----- og-cover ----- */

async function ogCover(fonts, makePortrait) {
  const W = 1200, H = 630;
  const ph = 470, pw = Math.round(ph * 0.8);           // портрет 4 : 5
  const px = W - 80 - pw, py = (H - ph) / 2;
  const x = 88;

  const parts = [
    textPath(fonts, 'Адвокат · рег. № 78/5868', { size: 24, weight: 450, x, y: 142, fill: C.muted }),
    textPath(fonts, 'Дмитриев', { size: 100, weight: 650, x: x - 4, y: 248, fill: C.fg, tracking: -2 }),
    textPath(fonts, 'Александр Николаевич', { size: 48, weight: 300, x, y: 312, fill: C.strong }),
    textPath(fonts, 'Арбитраж, взыскание долгов,', { size: 28, weight: 400, x, y: 412, fill: C.strong }),
    textPath(fonts, 'семейные дела и раздел имущества', { size: 28, weight: 400, x, y: 450, fill: C.strong }),
    textPath(fonts, 'Санкт-Петербург · Великий Новгород', { size: 24, weight: 450, x, y: 512, fill: C.muted }),
    textPath(fonts, '+7 (921) 730-03-05', { size: 32, weight: 600, x, y: 560, fill: C.accentText })
  ];
  const widest = Math.max(...parts.map((p) => p.width));
  if (x + widest > px - 32) console.log(`  ! текст (${Math.round(x + widest)} px) заходит на портрет (${px} px)`);

  // Без фона: зелёное поле даёт sharp.create, а этот слой ложится поверх портрета
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
  <rect x="20.5" y="20.5" width="${W - 41}" height="${H - 41}" fill="none" stroke="${C.accent}" stroke-opacity="0.55" stroke-width="1.5"/>
  <rect x="27.5" y="27.5" width="${W - 55}" height="${H - 55}" fill="none" stroke="${C.accent}" stroke-opacity="0.35" stroke-width="1"/>
  <rect x="${x}" y="344" width="80" height="1.5" fill="${C.accent}"/>
  <rect x="${x}" y="348.5" width="80" height="1.5" fill="${C.accent}"/>
  ${parts.map((p) => p.svg).join('\n  ')}
  <rect x="${px + 10.5}" y="${py + 10.5}" width="${pw - 21}" height="${ph - 21}" fill="none" stroke="${C.accent}" stroke-opacity="0.7" stroke-width="1"/>
</svg>`;

  const photo = await makePortrait(pw).resize(pw, ph).png().toBuffer();
  const frame = Buffer.from(svg);
  const out = path.join(IMG, 'og-cover.jpg');
  // Портрет кладётся под SVG: рамка-кант рисуется поверх снимка
  await sharp({ create: { width: W, height: H, channels: 3, background: C.plate } })
    .composite([{ input: photo, left: px, top: py }, { input: frame, left: 0, top: 0 }])
    .jpeg({ quality: 86, mozjpeg: true, progressive: true })
    .toFile(out);
  console.log('→ og-cover');
  log(out, W, H);
}

/* ----- favicon.ico ----- */

// ICO с PNG внутри (поддерживается всеми браузерами с Windows Vista и IE 9)
async function favicon() {
  const svgText = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="4" fill="${C.plate}"/>
  <rect x="7" y="7" width="50" height="50" fill="none" stroke="${C.accent}" stroke-width="2.5"/>
  <path fill="${C.fg}" d="${MONO_64}"/>
</svg>
`;
  fs.writeFileSync(path.join(IMG, 'favicon.svg'), svgText);
  const svg = Buffer.from(svgText);
  const sizes = [16, 32, 48];
  const pngs = [];
  for (const s of sizes) pngs.push(await sharp(svg, { density: 72 * s / 64 * 4 }).resize(s, s).png().toBuffer());

  const header = Buffer.alloc(6 + 16 * sizes.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);                 // тип: иконка
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((s, i) => {
    const e = 6 + 16 * i;
    header.writeUInt8(s, e);                  // ширина
    header.writeUInt8(s, e + 1);              // высота
    header.writeUInt16LE(1, e + 4);           // плоскости
    header.writeUInt16LE(32, e + 6);          // бит на пиксель
    header.writeUInt32LE(pngs[i].length, e + 8);
    header.writeUInt32LE(offset, e + 12);
    offset += pngs[i].length;
  });
  const out = 'favicon.ico';
  fs.writeFileSync(out, Buffer.concat([header, ...pngs]));
  console.log('→ favicon');
  log(out, sizes.join('/'), '');

  // apple-touch-icon 180 × 180: без прозрачности и скругления — iOS скругляет
  // углы сам; поля вокруг рамки шире, чтобы знак не прилипал к краю маски
  const touchSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="${C.plate}"/>
  <g transform="translate(6.4 6.4) scale(0.8)">
    <rect x="7" y="7" width="50" height="50" fill="none" stroke="${C.accent}" stroke-width="2.5"/>
    <path fill="${C.fg}" d="${MONO_64}"/>
  </g>
</svg>`;
  const touch = 'apple-touch-icon.png';
  await sharp(Buffer.from(touchSvg), { density: 72 * 180 / 64 * 2 }).resize(180, 180).png().toFile(touch);
  log(touch, 180, 180);
}

(async () => {
  await buildSet('hero');
  const makePortrait = await buildSet('about');
  const fonts = await loadFonts();
  await ogCover(fonts, makePortrait);
  await favicon();
})().catch((err) => { console.error('Ошибка:', err.message); process.exit(1); });
NODE

node "$TMP/build-images.cjs"

echo
echo "Готово. index.html менять не нужно: пути к фото и превью прежние."
