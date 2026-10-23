# Сайт адвоката Дмитриева А. Н. — advokat-dan.online

Статичный сайт без фреймворков: главная `index.html`, политика `privacy/index.html`,
страница ошибки `404.html`; стили `css/style.css`, скрипт `js/main.js`.
Хостинг — Apache (REG.RU), настройки в `.htaccess`.

## Сборка

```bash
bash build-images.sh   # фото (AVIF/WebP/JPG), og-cover, favicon, apple-touch-icon
bash build.sh          # CSS/JS → *.min.*, домен, ?v=, CSP, sitemap, dist/ и zip
```

Нужен Node.js 18+; инструменты npx/npm скачивает сам, в проекте нет `node_modules`.
`build.sh` в конце собирает **`dist/`** и **`advokat-dan-online.zip`** — только файлы
для сервера (без `.git`, README, `*.sh`, `tools/`, `screenshots/`, `assets/img/src/`).

## Настройки — где что менять

| Что | Где | После правки |
|---|---|---|
| Домен | `SITE_URL` в начале `build.sh` (сейчас `https://advokat-dan.online`) | `bash build.sh` |
| Яндекс.Метрика | `METRIKA_ID` в начале `js/main.js` (пусто — Метрики и плашки cookie нет) | `bash build.sh` |
| Яндекс.Вебмастер | `YANDEX_VERIFICATION` в `build.sh` — только значение `content` | `bash build.sh` |
| Ссылка на студию в подвале | `STUDIO_URL` в `build.sh` (пусто — просто текст) | `bash build.sh` |
| MAX | В `SITE` (`js/main.js`): `maxPhone` / `maxPhoneText` — номер, `max` — ссылка на профиль. Пока `max: ''`, кнопки MAX копируют номер в буфер и показывают «Номер скопирован — найдите его в MAX» (по номеру MAX ссылок не открывает). Задан `'https://max.ru/u/…'` — кнопки ведут на профиль, `build.sh` добавит его в `sameAs` | `bash build.sh` |
| Телефоны, почта, Telegram | объект `SITE` в `js/main.js` + запасные значения в разметке и JSON-LD | `bash build.sh` |
| Фото | первый экран — `assets/img/src/hero-cutout.png` (в полный рост, без фона, 2 : 3); «Об адвокате» — `about.jpg` (10 : 13) | `bash build-images.sh`, затем `bash build.sh` |

Шапка, подвал, плашка cookie и мобильная панель повторены в трёх страницах
(`index.html`, `privacy/index.html`, `404.html`) — при правке меняйте все три.
У `404.html` пути от корня (`/css/…`): она открывается по любому адресу.

## Фото первого экрана без фона

`hero-cutout.png` вырезан из `hero.jpg` скриптом `tools/cutout.py`: маска — rembg
(модель birefnet-portrait), затем очистка цвета краёв, чтобы по контуру волос
и пиджака не оставался серый ореол студийного фона. Новый снимок:

```bash
pip install "rembg[cpu]"
python tools/cutout.py        # hero.jpg → hero-cutout.png (модель ~1 ГБ скачается при первом запуске)
bash build-images.sh          # прозрачные AVIF/WebP + запасной PNG
bash build.sh
```

Перед публикацией — посмотреть края на зелёном: волосы, пальцы, очки. На десктопе
фигура стоит справа на всю высоту первого экрана (от шапки до полосы «Приём / Офисы»),
на планшете и телефоне — сверху, низ растворяется в фоне.

## Яндекс.Метрика и cookie

Метрика загружается только после кнопки «Понятно» в плашке о cookie; согласие —
в `localStorage` (ключ `cookie-consent`). Пока `METRIKA_ID` пуст, плашки нет: без
Метрики сайт cookie не ставит. Вебвизор и карта кликов выключены — политика их
не описывает. На `/privacy/` есть кнопка «Отозвать согласие».

Цели — в Метрике создать цели типа **«JavaScript-событие»** с идентификаторами:

| Идентификатор | Клик |
|---|---|
| `click_phone` | любая ссылка «Позвонить» / номер телефона |
| `click_email` | «Написать на почту» / адрес почты |
| `click_telegram` | Telegram |
| `click_max` | MAX |

CSP в `.htaccess` уже разрешает Метрику (`mc.yandex.ru`, `yastatic.net`).

## Выкладка на REG.RU

Порядок важен: сначала сертификат, потом файлы — в `.htaccess` включена
переадресация на https, без сертификата браузер покажет предупреждение.

1. **Домен на хостинге.** В личном кабинете REG.RU: «Домены» → advokat-dan.online →
   DNS-серверы — серверы хостинга REG.RU (`ns1.hosting.reg.ru`, `ns2.hosting.reg.ru`),
   если домен и хостинг в одном аккаунте, это обычно уже так. В панели хостинга
   (ISPmanager) домен должен быть добавлен как сайт: «Сайты» → «Создать», имя
   `advokat-dan.online`, псевдоним `www.advokat-dan.online`.
2. **SSL Let's Encrypt.** В ISPmanager: «SSL-сертификаты» → «Создать» → тип
   «Let's Encrypt» → домен `advokat-dan.online` и `www.advokat-dan.online` →
   «Ок». Выпуск занимает от нескольких минут до часа (DNS должен уже указывать
   на хостинг). В личном кабинете REG.RU то же: «Хостинг» → «SSL-сертификаты» →
   бесплатный Let's Encrypt. Сертификат продлевается сам.
3. **Файлы.** ISPmanager → «Менеджер файлов» → папка сайта
   **`www/advokat-dan.online/`**. Удалить заглушку хостинга (`index.html`/`index.php`),
   загрузить `advokat-dan-online.zip`, выделить → «Извлечь» в эту же папку.
   `index.html` должен лежать прямо в `www/advokat-dan.online/`, не во вложенной
   папке. `.htaccess` — тоже там (файл скрытый: включите показ скрытых файлов).
   Через FTP — то же содержимое `dist/` в ту же папку.
4. **Проверка.** Открыть `http://advokat-dan.online` и `https://www.advokat-dan.online`
   — оба должны перейти на `https://advokat-dan.online/`. Открыть несуществующий
   адрес — фирменная страница 404. Если браузер пишет «слишком много
   переадресаций», закомментируйте в `.htaccess` правило «http → https» (три строки)
   и включите в ISPmanager у сайта «Перенаправлять HTTP-запросы в HTTPS».
5. Когда https работает стабильно, можно включить HSTS (строка в конце `.htaccess`).

Если панель — cPanel, папка сайта называется `public_html/`, SSL — «SSL/TLS Status»
→ «Run AutoSSL».

## Демо на GitHub Pages

Для показа клиенту: https://elhpiv-hash.github.io/advokat-dmitriev/ — копия сайта
с noindex (в поиск не попадает). Обновить демо после правок:

```bash
bash tools/publish-pages.sh
```

Скрипт собирает сайт и кладёт копию `dist/` новым коммитом в ветку `gh-pages` (она целиком
генерируется скриптом). Боевая сборка в `dist/` от этого не меняется.

## После публикации — чек-лист

- [ ] Создать счётчик в Яндекс.Метрике, вписать номер в `METRIKA_ID` (`js/main.js`),
      создать четыре цели (таблица выше), `bash build.sh`, залить `dist/` заново.
- [ ] Добавить сайт в Яндекс.Вебмастер, код подтверждения — в `YANDEX_VERIFICATION`
      (`build.sh`), `bash build.sh`, залить, нажать «Проверить» в Вебмастере.
- [ ] В Вебмастере: «Индексирование» → «Файлы Sitemap» → `https://advokat-dan.online/sitemap.xml`.
- [ ] Ссылку на сайт — в карточки Яндекс Бизнес (оба офиса), 2ГИС (оба офиса)
      и в профиль на HARANT.
- [ ] Когда клиент пришлёт ссылку на профиль MAX — вписать в `SITE.max` (`js/main.js`),
      `bash build.sh`. До этого кнопки MAX копируют номер — так и задумано.
- [ ] Дата редакции политики (`privacy/index.html`, сейчас 23 октября 2026 г.) —
      поставить фактическую дату публикации, если она другая.
