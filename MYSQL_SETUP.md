# Установка MySQL на сервере (Ubuntu)

## Информация о SSH ключе

Ваш SSH ключ находится в:
- **Приватный ключ:** `C:\Users\vsush\.ssh\id_rsa`
- **Публичный ключ:** `C:\Users\vsush\.ssh\id_rsa.pub`
- **Название:** `id_rsa` / `id_rsa.pub`

Для подключения к серверу используйте:
```bash
ssh -i C:\Users\vsush\.ssh\id_rsa root@45.153.70.209
```

Или если ключ добавлен в ssh-agent:
```bash
ssh root@45.153.70.209
```

## Быстрая установка

**Самый простой способ:** Файлы уже в репозитории, просто задеплойте проект:
```powershell
.\deploy.ps1
```
После деплоя файлы `setup_mysql.sh` и `init_database.sql` будут на сервере.

**Или вручную:**

1. Подключитесь к серверу:
```bash
ssh root@45.153.70.209
```

2. Загрузите скрипт установки на сервер:

**Вариант 1: Через SCP (из Windows PowerShell или Linux/Mac):**
```bash
scp setup_mysql.sh root@45.153.70.209:/var/www/tg-text.ru/
scp init_database.sql root@45.153.70.209:/var/www/tg-text.ru/
```

**Вариант 2: Через Git (если файлы уже в репозитории):**
```bash
ssh root@45.153.70.209
cd /var/www/tg-text.ru
git pull origin main  # или git pull production main
```

**Вариант 3: Вручную через SSH:**
```bash
ssh root@45.153.70.209
cd /var/www/tg-text.ru
# Создайте файл setup_mysql.sh и скопируйте его содержимое
nano setup_mysql.sh
# Вставьте содержимое файла, сохраните (Ctrl+O, Enter, Ctrl+X)
```

3. Выполните установку:
```bash
chmod +x setup_mysql.sh
./setup_mysql.sh
```

## Ручная установка (Ubuntu)

1. Обновите список пакетов:
```bash
apt-get update
```

2. Установите MySQL:
```bash
apt-get install -y mysql-server
```

3. Запустите MySQL:
```bash
systemctl enable mysql
systemctl start mysql
```

3. Создайте базу данных:
```bash
mysql -u root -p < init_database.sql
```

## Настройка подключения

После установки MySQL, обновите переменные окружения в `app.js` или создайте файл `.env`:

```env
DB_HOST=localhost
DB_USER=tg_text_user
DB_PASSWORD=tg_text_password_2024
DB_NAME=tg_text_db
```

## Проверка работы

1. Проверьте подключение к MySQL:
```bash
mysql -u tg_text_user -ptg_text_password_2024 tg_text_db
```

2. Проверьте таблицу:
```sql
USE tg_text_db;
SELECT COUNT(*) FROM user_requests;
DESCRIBE user_requests;
```

3. Проверьте API:
```bash
curl http://localhost:5000/api/health
```

## Структура таблицы

Таблица `user_requests` содержит:
- `id` - уникальный идентификатор запроса
- `user_ip` - IP адрес пользователя
- `user_agent` - User-Agent браузера
- `request_text` - исходный текст запроса
- `exclude_words` - слова для исключения
- `result_text` - результат обработки
- `created_at` - время создания запроса

## API Endpoints

- `POST /api/process` - обработка текста (автоматически сохраняет в БД)
- `GET /api/history` - история запросов текущего пользователя
- `GET /api/all-requests` - все запросы (административный)
- `GET /api/health` - проверка работоспособности (включая БД)

