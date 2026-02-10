# Решение проблем с API

## Ошибка "Failed to fetch"

Если на сайте появляется ошибка "Failed to fetch", выполните следующие шаги:

### 1. Проверка API на сервере

```bash
# Проверка здоровья API
curl https://tg-text.ru/api/health

# Должен вернуть: {"status":"ok","service":"text-processor"}
```

### 2. Проверка статуса сервисов

```bash
ssh root@45.153.70.209

# Проверка Node.js API
systemctl status text-processor

# Проверка Nginx
systemctl status nginx

# Проверка порта
ss -tlnp | grep ':5000'
```

### 3. Проверка логов

```bash
# Логи API
journalctl -u text-processor -n 50 --no-pager

# Логи Nginx
tail -50 /var/www/tg-text.ru/logs/error.log
tail -50 /var/www/tg-text.ru/logs/access.log | grep api
```

### 4. Проверка в браузере

1. Откройте сайт https://tg-text.ru
2. Нажмите F12 (открыть консоль разработчика)
3. Перейдите на вкладку "Console"
4. Попробуйте обработать текст
5. Проверьте ошибки в консоли

### 5. Проверка конфигурации Nginx

```bash
# Проверка синтаксиса
nginx -t

# Проверка конфигурации API
cat /etc/nginx/conf.d/tg-text.ru.conf | grep -A 10 'location /api/'
```

### 6. Перезапуск сервисов

```bash
# Перезапуск API
systemctl restart text-processor

# Перезапуск Nginx
systemctl reload nginx
```

### 7. Тестирование API напрямую

```bash
# Тест через curl
curl -X POST https://tg-text.ru/api/process \
  -H "Content-Type: application/json" \
  -d '{"text":"привет мир","exclude_words":""}'

# Должен вернуть JSON с результатом
```

## Частые проблемы

### Проблема: API не отвечает

**Решение:**
```bash
systemctl restart text-processor
systemctl status text-processor
```

### Проблема: 400 Bad Request

**Причина:** Неверный формат JSON или пустой текст

**Решение:** Проверьте что текст не пустой и JSON правильно сформирован

### Проблема: CORS ошибка

**Решение:** CORS уже настроен в Express. Если проблема сохраняется:
```bash
# Проверьте что CORS middleware загружен
grep -i cors /var/www/tg-text.ru/api/app.js
```

### Проблема: Nginx не проксирует запросы

**Решение:**
```bash
# Проверьте конфигурацию
nginx -t
systemctl reload nginx

# Проверьте что proxy_pass правильный
cat /etc/nginx/conf.d/tg-text.ru.conf | grep proxy_pass
```

## Контакты для поддержки

Если проблема не решена, проверьте:
- Логи API: `journalctl -u text-processor -f`
- Логи Nginx: `tail -f /var/www/tg-text.ru/logs/error.log`
- Консоль браузера (F12)

