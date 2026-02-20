# Руководство по миграции на React

## Что было сделано

1. ✅ Создано React приложение с React Router
2. ✅ Добавлены страницы регистрации и авторизации
3. ✅ Реализована JWT авторизация на бэкенде
4. ✅ Обновлены скрипты деплоя для сборки React
5. ✅ Настроена конфигурация Nginx для SPA routing

## Что нужно сделать перед деплоем

### 1. Обновить базу данных на сервере

Подключитесь к серверу и выполните:

```bash
ssh root@45.153.70.209
mysql -u root -p tg_text_db < /var/www/tg-text.ru/update_database.sql
```

Или если файл еще не на сервере:

```bash
mysql -u root -p tg_text_db < update_database.sql
```

Это создаст таблицу `users` и добавит связь с `user_requests`.

### 2. Установить зависимости на сервере

На сервере должен быть установлен Node.js и npm. Проверьте:

```bash
node --version
npm --version
```

Если не установлены, установите:

```bash
pacman -S nodejs npm
```

### 3. Обновить зависимости API на сервере

После деплоя на сервере выполните:

```bash
cd /var/www/tg-text.ru
npm install
systemctl restart text-processor
```

### 4. Изменить JWT_SECRET в production

В файле `app.js` измените:

```javascript
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production-2024';
```

Или установите переменную окружения на сервере в `text-processor.service`:

```ini
Environment=JWT_SECRET=ваш-секретный-ключ-для-production
```

## Деплой

После выполнения всех шагов выше:

```powershell
.\deploy.ps1
```

Скрипт автоматически:
1. Соберет React приложение локально
2. Закоммитит изменения
3. Отправит на сервер
4. Сервер соберет приложение и развернет

## Проверка работы

1. Откройте https://tg-text.ru
2. Должна открыться страница авторизации
3. Зарегистрируйте нового пользователя
4. После входа вы увидите главную страницу с формой обработки текста

## Структура файлов

```
C:\tg\
├── src/                    # React приложение
│   ├── pages/             # Страницы (Home, Login, Register)
│   ├── components/        # Компоненты
│   ├── contexts/          # React контексты
│   └── styles/            # CSS стили
├── app.js                 # Node.js API сервер
├── package.json           # Зависимости
├── vite.config.js         # Конфигурация сборки
├── deploy.ps1             # Скрипт деплоя
└── update_database.sql    # Обновление БД
```

## Возможные проблемы

### Ошибка "npm не найден" при деплое
Установите Node.js и npm на локальной машине:
- Скачайте с https://nodejs.org/
- Или через Chocolatey: `choco install nodejs`

### Ошибка сборки на сервере
Проверьте, что на сервере установлен Node.js >= 14:
```bash
node --version
```

### Страница не открывается после деплоя
Проверьте логи Nginx:
```bash
tail -f /var/www/tg-text.ru/logs/error.log
```

### API возвращает 401 при запросах
Проверьте, что токен передается в заголовке Authorization:
```
Authorization: Bearer <token>
```

