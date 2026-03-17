# Деплой — готово к работе

## Секреты (ключи и пароли не в Git)

Ключи API и пароли **не хранятся в репозитории**. Они задаются в файле **на сервере**:

**Файл:** `/var/www/tg-text.ru/.env`

Создайте его на сервере один раз (после первого деплоя или при смене ключей):

```bash
ssh root@45.153.70.209
nano /var/www/tg-text.ru/.env
```

Содержимое (подставьте свои значения):

```
DEEPSEEK_API_KEY=sk-ваш_новый_ключ_из_личного_кабинета_DeepSeek
TELEGRAM_BOT_TOKEN=123456:ABC-токен_бота_от_BotFather
DB_HOST=localhost
DB_USER=tg_text_user
DB_PASSWORD=ваш_пароль_БД
DB_NAME=tg_text_db
JWT_SECRET=длинная_случайная_строка_для_JWT
```

Сохраните и выполните: `chmod 600 /var/www/tg-text.ru/.env`, затем `systemctl restart text-processor telegram-bot`.

Шаблон переменных — в файле `.env.example` (без реальных значений, его можно коммитить).

---

## Обычный деплой (после первой настройки)

Из папки проекта выполните:

```powershell
.\deploy.ps1
```

Нужны: **Git**, **SSH-ключ** (см. ниже). На сервере при `git push` автоматически запустится hook **post-receive**: сборка фронта, копирование app.js и bot.js, миграции БД, перезапуск сервисов и nginx.

---

## Первый раз: настройка SSH и сервера

### 1. SSH-ключ (локально, один раз)

```powershell
.\create_ssh_key.ps1
```

Выведите публичный ключ и добавьте его на сервер:

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_rsa_tg_text.pub"
```

На сервере (через пароль или консоль хостинга):

```bash
mkdir -p ~/.ssh
echo "ВАШ_ПУБЛИЧНЫЙ_КЛЮЧ" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### 2. Hook post-receive на сервере (один раз)

На сервере в каталоге репозитория:

```bash
cd /var/www/tg-text.ru
# Если папка .git/hooks уже есть — скопировать post-receive из репозитория в hook
cp /var/www/tg-text.ru/post-receive .git/hooks/post-receive
# Или после первого клона/настройки bare — скопировать содержимое post-receive в .git/hooks/post-receive
chmod +x .git/hooks/post-receive
```

При последующих деплоях hook будет обновляться сам из репозитория.

### 3. Сервисы и БД на сервере (один раз)

- Установлены **Node.js**, **npm**, **MySQL**, **nginx**.
- Создана БД и пользователь (см. **init_database.sql** / **MYSQL_SETUP.md**).
- В `/etc/systemd/system/` лежат **text-processor.service** и **telegram-bot.service** (при первом деплое они копируются из репозитория; при необходимости создайте их вручную из файлов в репозитории).
- В сервисах заданы переменные окружения: **DEEPSEEK_API_KEY**, для бота — **TELEGRAM_BOT_TOKEN**.

---

## Обновление только бота (без полного деплоя)

Если меняли только **bot.js**:

```powershell
.\deploy_bot_update.ps1
```

Нужен модуль **Posh-SSH** (установится по запросу). Скрипт копирует bot.js на сервер и перезапускает **telegram-bot**.

---

## Что делает post-receive при каждом deploy.ps1

1. Сборка React (`npm run build`) → копирование **dist/** в **public_html**.
2. Копирование **app.js** и **bot.js** в **/var/www/tg-text.ru/api/**.
3. Установка зависимостей API (в т.ч. node-telegram-bot-api при необходимости).
4. Миграция БД **migrations/add_prompt_and_count.sql** (если файл есть; повторный запуск безопасен).
5. Копирование **text-processor.service** и **telegram-bot.service** в systemd, перезапуск **text-processor** и **telegram-bot**.
6. Копирование **nginx_tg-text.ru.conf**, перезагрузка nginx.
7. Обновление самого **post-receive** из репозитория.

После выполнения этих шагов проект готов к работе через `.\deploy.ps1`.
