# Сайт адвоката Дмитриева А. Н.

Статичный одностраничник: `index.html`, `css/style.css`, `js/main.js`, без фреймворков.
Хостинг — любой Apache (REG.RU и т. п.), настройки в `.htaccess`.
README, `*.sh` и папка `tools/` с сервера не отдаются (`.htaccess`).

## Сборка

```bash
bash build.sh          # CSS/JS → *.min.*, адрес сайта, ?v=, хеш CSP, lastmod
bash build-images.sh   # портрет (AVIF/WebP/JPG), og-cover.jpg, favicon.ico
```

Нужен Node.js 18+; инструменты npx/npm скачивает сам, в проекте нет `node_modules`.

## Домен

Задаётся в одном месте — строка `SITE_URL` в начале `build.sh` (сейчас `https://example.ru`).
Поменять и запустить `bash build.sh`: адрес обновится в canonical, Open Graph, Twitter,
JSON-LD, `robots.txt`, `sitemap.xml` и в редиректе www в `.htaccess`.

## Фото

Положить портрет в `assets/img/src/dmitriev.jpg` (лучше от 1200 × 1500, вертикальный)
и запустить `bash build-images.sh`. Пока исходника нет, на тех же путях — заглушка
с монограммой. `index.html` трогать не нужно; og-cover пересоберётся с портретом.

## Контакты

Телефоны, почта и мессенджеры — объект `SITE` в `js/main.js`; запасные значения
для работы без JS — в разметке, для поисковиков — в JSON-LD в `<head>`.
