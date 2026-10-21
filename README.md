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

## Цвет

Палитра «Зимний дворец» (вариант C, выбран клиентом): малахитовая зелень, тёплый белый,
золото. Цвета — в начале `css/style.css` (блок `:root`); og-cover и favicon собирает
`build-images.sh` в тех же цветах.

## Фото

Два снимка, исходники — в `assets/img/src/` (подойдут .jpg, .png, .webp):

- `hero.jpg` — первый экран, фото в полный рост (лучше от 1200 × 1500). Пока его нет,
  в первом экране заглушка с монограммой.
- `about.jpg` — портрет по пояс в «Об адвокате» (сейчас 285 × 429 — мал, но в блоке
  шириной 20 rem это почти не заметно).

Положить файл и запустить `bash build-images.sh`.
`index.html` трогать не нужно; og-cover берёт портрет из `about.jpg`.

## Контакты

Телефоны, почта и мессенджеры — объект `SITE` в `js/main.js`; запасные значения
для работы без JS — в разметке, для поисковиков — в JSON-LD в `<head>`.

**MAX:** ссылка на профиль — `max: 'MAX_URL_TODO'` в `SITE` (`js/main.js`). Вставить
адрес вида `https://max.ru/…` и запустить `bash build.sh`. Пока там не `https://…`,
кнопки MAX (первый экран, меню, контакты) и строка MAX в контактах скрыты.
