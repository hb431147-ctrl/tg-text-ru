# React приложение - Документация

## Что реализовано

1. ✅ React приложение с React Router
2. ✅ Страницы регистрации и авторизации
3. ✅ JWT авторизация на бэкенде
4. ✅ Автоматическая сборка React при деплое
5. ✅ Настроена конфигурация Nginx для SPA routing

## Структура проекта

```
C:\tg\
├── src/                    # React приложение
│   ├── pages/             # Страницы (Home, Login, Register)
│   ├── components/        # Компоненты
│   ├── contexts/          # React контексты (AuthContext)
│   └── styles/            # CSS стили
├── app.js                 # Node.js API сервер
├── package.json           # Зависимости
├── vite.config.js         # Конфигурация сборки Vite
├── deploy.ps1             # Скрипт деплоя
└── update_database.sql    # SQL скрипт для БД
```

## Деплой

Для деплоя выполните:

```powershell
.\deploy.ps1
```

Скрипт автоматически:
1. Соберет React приложение (если npm доступен локально)
2. Закоммитит изменения в Git
3. Отправит на сервер через Git push
4. Сервер автоматически соберет приложение через `post-receive` hook

## API Endpoints

### Авторизация
- `POST /api/auth/register` - Регистрация нового пользователя
- `POST /api/auth/login` - Вход пользователя

### Обработка текста
- `POST /api/process` - Обработка текста (перемешивание слов)
- `GET /api/history` - История запросов (требует авторизации)

### Системные
- `GET /api/health` - Проверка работоспособности API

## Структура базы данных

### Таблица `users`
- `id` - ID пользователя
- `email` - Email (уникальный)
- `password_hash` - Хеш пароля
- `name` - Имя пользователя
- `created_at` - Дата регистрации

### Таблица `user_requests`
- `id` - ID запроса
- `user_id` - ID пользователя (связь с users)
- `user_ip` - IP адрес
- `request_text` - Исходный текст
- `exclude_words` - Слова для исключения
- `result_text` - Результат обработки
- `created_at` - Время создания

## Проверка работы

1. Откройте https://tg-text.ru
2. Зарегистрируйте нового пользователя
3. Войдите в систему
4. Используйте форму для обработки текста

## Устранение неполадок

### Страница не открывается
Проверьте логи Nginx:
```bash
ssh root@45.153.70.209 'tail -f /var/www/tg-text.ru/logs/error.log'
```

### API не отвечает
Проверьте статус сервиса:
```bash
ssh root@45.153.70.209 'systemctl status text-processor'
```

Проверьте логи:
```bash
ssh root@45.153.70.209 'journalctl -u text-processor -n 50'
```

### Ошибка авторизации
Проверьте, что токен передается в заголовке:
```
Authorization: Bearer <token>
```
