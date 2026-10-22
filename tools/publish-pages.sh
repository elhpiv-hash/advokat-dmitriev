#!/usr/bin/env bash
# ==========================================================================
#  tools/publish-pages.sh — демо сайта на GitHub Pages для показа клиенту
#  --------------------------------------------------------------------------
#  Собирает сайт (build.sh) и публикует копию dist/ в ветку gh-pages:
#      https://elhpiv-hash.github.io/advokat-dmitriev/
#
#  Отличия демо от боевой сборки (сами исходники и dist/ не меняются):
#  • абсолютные URL (canonical, Open Graph, JSON-LD, sitemap) — на адрес Pages,
#    чтобы превью ссылки в мессенджерах показывало картинку;
#  • noindex на всех страницах и «Disallow: /» в robots.txt — копия не попадёт
#    в поиск и не будет конкурировать с advokat-dan.online;
#  • 404.html — пути с префиксом /advokat-dmitriev/ (сайт в подпапке);
#  • .htaccess убран (на Pages не действует), добавлен .nojekyll.
#
#  Запуск:   bash tools/publish-pages.sh
#  Ветка gh-pages целиком генерируется этим скриптом и перезаписывается
#  при каждом запуске (push --force) — руками её не правят.
# ==========================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

REPO="elhpiv-hash/advokat-dmitriev"
PAGES_URL="https://elhpiv-hash.github.io/advokat-dmitriev/"

bash build.sh >/dev/null
echo "→ сборка: dist/ готов"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R dist/. "$TMP/"
rm -f "$TMP/.htaccess"
touch "$TMP/.nojekyll"

node - "$TMP" "$PAGES_URL" <<'NODE'
const fs = require('fs');
const path = require('path');
const [dir, pagesUrl] = process.argv.slice(2);
const prefix = new URL(pagesUrl).pathname;            // /advokat-dmitriev/
const file = (rel) => path.join(dir, rel);
const read = (rel) => fs.readFileSync(file(rel), 'utf8');

const prodUrl = read('index.html').match(/<link rel="canonical" href="([^"]+)">/)[1];
const swap = (text) => text.split(prodUrl).join(pagesUrl);
const noindex = '\n  <meta name="robots" content="noindex, nofollow">';

for (const rel of ['index.html', 'privacy/index.html', '404.html']) {
  let html = swap(read(rel));
  html = html.replace(/\n {2}<meta name="robots" content="[^"]*">/, '');
  html = html.replace(/(<meta name="viewport"[^>]*>)/, `$1${noindex}`);
  if (rel === '404.html') {
    // пути от корня домена → от корня демо (/advokat-dmitriev/…)
    html = html.replace(/\b(href|src)="\/(?!\/)/g, `$1="${prefix}`);
  }
  fs.writeFileSync(file(rel), html);
}
fs.writeFileSync(file('sitemap.xml'), swap(read('sitemap.xml')));
fs.writeFileSync(file('robots.txt'), '# Демо для показа — в поиск не нужно\nUser-agent: *\nDisallow: /\n');
console.log(`→ демо: ${prodUrl} → ${pagesUrl}, noindex`);
NODE

cd "$TMP"
git init -q
git checkout -q -b gh-pages
git add -A
git commit -q -m "Демо для показа: $(date '+%Y-%m-%d %H:%M')

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -q --force "https://github.com/$REPO.git" gh-pages
echo "→ опубликовано: $PAGES_URL (обновление Pages — около минуты)"
