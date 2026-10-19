#!/usr/bin/env bash
# ==========================================================================
#  build.sh — сборка сайта
#  --------------------------------------------------------------------------
#  1. css/style.css → css/style.min.css   (clean-css-cli 5)
#  2. js/main.js    → js/main.min.js      (terser 5)
#  3. Адрес сайта из SITE_URL — в canonical, Open Graph, Twitter, JSON-LD
#     (index.html), robots.txt, sitemap.xml и в редирект www (.htaccess).
#  4. ?v= у style.min.css и main.min.js — хеш содержимого: статика кэшируется
#     на год (immutable), новый хеш сразу обходит кэш. Вручную не трогать.
#  5. sha256 инлайн-скрипта из <head> — в CSP (.htaccess).
#  6. lastmod в sitemap.xml — сегодняшняя дата.
#
#  Запуск:   bash build.sh
#  Нужен Node.js 18+ — npx сам скачает инструменты при первом запуске.
#  Фото, og-cover и favicon.ico собирает отдельный скрипт: build-images.sh.
# ==========================================================================

set -euo pipefail

# Работаем из папки скрипта: пути не зависят от того, откуда его запустили.
cd "$(dirname "$0")"

# ----- Адрес сайта ----------------------------------------------------------
# ЕДИНСТВЕННОЕ место, где задаётся домен. Поменяйте строку и запустите
# bash build.sh — адрес обновится во всех файлах сразу. Можно с подпапкой:
# "https://user.github.io/advokat-dmitriev". Слэш в конце не обязателен.
SITE_URL="https://example.ru"

CSS_SRC="css/style.css"
CSS_MIN="css/style.min.css"
JS_SRC="js/main.js"
JS_MIN="js/main.min.js"

if ! command -v npx >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
  echo "Ошибка: не найден Node.js (node, npx). Установите Node.js 18+ (https://nodejs.org)." >&2
  exit 1
fi

for file in "$CSS_SRC" "$JS_SRC" index.html robots.txt sitemap.xml .htaccess; do
  [ -f "$file" ] || { echo "Ошибка: нет файла $file" >&2; exit 1; }
done

# Версии зафиксированы мажором (@5): сборка воспроизводима и не сломается
# от несовместимого релиза. --yes — не спрашивать подтверждение установки.

echo "→ CSS: clean-css"
# -O1 — безопасный уровень: только локальные сокращения внутри правил.
# -O2 умеет переставлять и сливать правила, а это может изменить каскад.
npx --yes --package=clean-css-cli@5 cleancss -O1 -o "$CSS_MIN" "$CSS_SRC"

echo "→ JS: terser"
# passes=2 — второй проход сжатия находит то, что открылось после первого.
npx --yes --package=terser@5 terser "$JS_SRC" \
  --compress passes=2 \
  --mangle \
  --comments false \
  --output "$JS_MIN"

echo "→ HTML: адрес сайта, версии файлов, хеш для CSP"
# Замены делает Node, а не sed: у sed -i разный синтаксис в Linux и macOS,
# а в адресе бывают символы, которые sed понял бы как спецсимволы.
node - "$SITE_URL" <<'NODE'
const fs = require('fs');
const crypto = require('crypto');

const fail = (msg) => { console.error('Ошибка: ' + msg); process.exit(1); };
const read = (file) => fs.readFileSync(file, 'utf8');

const siteUrl = process.argv[process.argv.length - 1].trim().replace(/\/+$/, '') + '/';
if (!/^https?:\/\/[^\s"'<>]+\/$/.test(siteUrl)) fail(`SITE_URL «${siteUrl}» — не похоже на адрес сайта`);

let html = read('index.html');
let robots = read('robots.txt');
let sitemap = read('sitemap.xml');
let htaccess = read('.htaccess');

// Текущий адрес берём из canonical: так скрипт знает, что именно заменять,
// и повторный запуск с тем же SITE_URL ничего не меняет.
const canonical = html.match(/<link rel="canonical" href="([^"]+)">/);
if (!canonical) fail('в index.html нет <link rel="canonical">');
const oldUrl = canonical[1];

if (oldUrl !== siteUrl) {
  const swap = (text) => text.split(oldUrl).join(siteUrl);
  html = swap(html);
  robots = swap(robots);
  sitemap = swap(sitemap);

  // .htaccess: закомментированный редирект www → без www
  const oldHost = new URL(oldUrl).host;
  const newHost = new URL(siteUrl).host;
  const esc = (host) => host.replace(/\./g, '\\.');
  htaccess = htaccess
    .split(`www${esc('.' + oldHost)}`).join(`www${esc('.' + newHost)}`)
    .split(`https://${oldHost}%`).join(`https://${newHost}%`);
  console.log(`  адрес: ${oldUrl} → ${siteUrl}`);
} else {
  console.log(`  адрес: ${siteUrl} (без изменений)`);
}

// ?v= — первые 10 знаков sha256 минифицированного файла
const version = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex').slice(0, 10);
html = html
  .replace(/(css\/style\.min\.css\?v=)[^"]*/, '$1' + version('css/style.min.css'))
  .replace(/(js\/main\.min\.js\?v=)[^"]*/, '$1' + version('js/main.min.js'));

// CSP: хеш текста единственного инлайн-скрипта без атрибутов (<script>…</script>)
const inline = html.match(/<script>([^<]*)<\/script>/);
if (!inline) fail('в index.html не найден инлайн-скрипт <script>…</script>');
const cspHash = crypto.createHash('sha256').update(inline[1]).digest('base64');
if (!/'sha256-[^']*'/.test(htaccess)) fail("в .htaccess не найден 'sha256-…' в CSP");
htaccess = htaccess.replace(/'sha256-[^']*'/, `'sha256-${cspHash}'`);

const today = new Date().toISOString().slice(0, 10);
sitemap = sitemap.replace(/<lastmod>[^<]*<\/lastmod>/, `<lastmod>${today}</lastmod>`);

fs.writeFileSync('index.html', html);
fs.writeFileSync('robots.txt', robots);
fs.writeFileSync('sitemap.xml', sitemap);
fs.writeFileSync('.htaccess', htaccess);
console.log(`  CSP: sha256-${cspHash}`);
NODE

# ----- Таблица размеров -----
# gzip — ориентир того, сколько реально уйдёт по сети при сжатии на сервере.

bytes() { wc -c < "$1" | tr -d ' '; }
gz()    { gzip -9 -c "$1" | wc -c | tr -d ' '; }
kb()    { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1024 }'; }
saved() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.0f %%", (1 - b / a) * 100 }'; }

# printf выравнивает по байтам, а кириллическая буква в UTF-8 — два байта.
# Поэтому в строках таблицы только ASCII, а заголовок выровнен вручную.
row() {
  local src="$1" min="$2"
  local s m g
  s=$(bytes "$src"); m=$(bytes "$min"); g=$(gz "$min")
  printf '  %-20s %14s %14s %14s %10s\n' "$min" "$(kb "$s")" "$(kb "$m")" "$(kb "$g")" "$(saved "$s" "$m")"
}

echo
echo "  Файл                   исходник, КБ   минифиц., КБ     с gzip, КБ   экономия"
echo "  -------------------- -------------- -------------- -------------- ----------"
row "$CSS_SRC" "$CSS_MIN"
row "$JS_SRC"  "$JS_MIN"
echo
echo "Готово."
